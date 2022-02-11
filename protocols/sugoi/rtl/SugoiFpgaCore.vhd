-------------------------------------------------------------------------------
-- Title      : SUGOI Protocol: https://confluence.slac.stanford.edu/x/3of_E
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Top-level for FPGA side
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity SugoiFpgaCore is
   generic (
      TPD_G           : time    := 1 ns;
      SIMULATION_G    : boolean := false;
      COMMON_CLK_G    : boolean := false;  -- Set true if timingClk & axilClk are same signal
      NUM_ADDR_BITS_G : positive;  -- Number of AXI-Lite address bits in the ASIC
      TX_POLARITY_G   : sl      := '0';
      RX_POLARITY_G   : sl      := '0';
      XIL_DEVICE_G    : string;  -- Either "7SERIES" or "ULTRASCALE" or "ULTRASCALE_PLUS"
      IODELAY_GROUP_G : string  := "DESER_GROUP";  -- Only used if XIL_DEVICE_G="7SERIES"
      REF_FREQ_G      : real    := 300.0);  -- Only used if XIL_DEVICE_G="7SERIES"
   port (
      -- SUGOI Serial Ports
      sugioRxP        : in  sl;
      sugioRxN        : in  sl;
      sugioTxP        : out sl;
      sugioTxN        : out sl;
      sugioClkP       : out sl;
      sugioClkN       : out sl;
      -- Timing and Trigger Interface (timingClk domain)
      timingClk       : in  sl;
      timingRst       : in  sl;
      sugioGlobalRst  : in  sl;
      sugioOpCode     : in  slv(7 downto 0);       -- 1-bit per Control code
      sugioStrobe     : out sl;         -- 1 strobe every 10 cycles
      sugioLinkup     : out sl;
      -- AXI-Lite Master Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity SugoiFpgaCore;

architecture mapping of SugoiFpgaCore is

   signal readMaster  : AxiLiteReadMasterType;
   signal readSlave   : AxiLiteReadSlaveType;
   signal writeMaster : AxiLiteWriteMasterType;
   signal writeSlave  : AxiLiteWriteSlaveType;


   signal rx            : sl;
   signal rxEncodeValid : sl;
   signal rxEncodeData  : slv(9 downto 0);
   signal rxSlip        : sl;

   signal gearboxAligned : sl;
   signal errorDet       : sl;
   signal dlyLoad        : sl;
   signal dlyCfg         : slv(8 downto 0);

   signal enUsrDlyCfg    : sl;
   signal usrDlyCfg      : slv(8 downto 0);
   signal bypFirstBerDet : sl;
   signal minEyeWidth    : slv(7 downto 0);
   signal lockingCntCfg  : slv(23 downto 0);

   signal rxDecodeValid : sl;
   signal rxDecodeData  : slv(7 downto 0);
   signal rxDecodeDataK : sl;
   signal rxCodeErr     : sl;
   signal rxDispErr     : sl;
   signal rxError       : sl;

   signal txStrobe      : sl;
   signal txDecodeData  : slv(7 downto 0);
   signal txDecodeDataK : sl;

   signal txEncodeValid : sl;
   signal txEncodeData  : slv(9 downto 0);
   signal tx            : sl;

   signal polarityRx : sl;
   signal polarityTx : sl;
   signal disableClk : sl;
   signal disableTx  : sl;

begin

   sugioLinkup <= gearboxAligned;
   sugioStrobe <= txStrobe;             -- 1 strobe every 10 cycles

   --------------------------------------------
   -- Move the AXI-Lite Bus to timingClk Domain
   --------------------------------------------
   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => COMMON_CLK_G,
         NUM_ADDR_BITS_G => (NUM_ADDR_BITS_G+4))  -- +4 for daisy chain device address support and for control/space address space
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         -- Master Interface
         mAxiClk         => timingClk,
         mAxiClkRst      => timingRst,
         mAxiReadMaster  => readMaster,
         mAxiReadSlave   => readSlave,
         mAxiWriteMaster => writeMaster,
         mAxiWriteSlave  => writeSlave);

   ---------------------------
   -- RX IDELAY + I/O Register
   ---------------------------
   U_Rx : entity surf.SugoiFpgaRx
      generic map (
         TPD_G           => TPD_G,
         SIM_DEVICE_G    => XIL_DEVICE_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G,
         REF_FREQ_G      => REF_FREQ_G)
      port map (
         -- Clock and Reset
         clk     => timingClk,
         rst     => timingRst,
         -- SELECTIO Ports
         rxP     => sugioRxP,
         rxN     => sugioRxN,
         -- Delay Configuration
         dlyLoad => dlyLoad,
         dlyCfg  => dlyCfg,
         -- Output
         inv     => polarityRx,
         rx      => rx);

   U_GearboxAligner : entity surf.SelectIoRxGearboxAligner
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => SIMULATION_G,
         DLY_STEP_SIZE_G => ite(XIL_DEVICE_G = "7SERIES", 16, 1),
         CODE_TYPE_G     => "LINE_CODE")
      port map (
         -- Clock and Reset
         clk             => timingClk,
         rst             => timingRst,
         -- Line-Code Interface (CODE_TYPE_G = "LINE_CODE")
         lineCodeValid   => rxDecodeValid,
         lineCodeErr     => rxCodeErr,
         lineCodeDispErr => rxDispErr,
         linkOutOfSync   => '0',
         -- 64b/66b Interface (CODE_TYPE_G = "SCRAMBLER")
         rxHeaderValid   => '0',
         rxHeader        => (others => '0'),
         -- Link Status and Gearbox Slip
         bitSlip         => rxSlip,
         -- IDELAY (DELAY_TYPE="VAR_LOAD") Interface
         dlyLoad         => dlyLoad,
         dlyCfg          => dlyCfg,
         -- Configuration Interface
         enUsrDlyCfg     => enUsrDlyCfg,
         usrDlyCfg       => usrDlyCfg,
         bypFirstBerDet  => bypFirstBerDet,
         minEyeWidth     => minEyeWidth,
         lockingCntCfg   => lockingCntCfg,
         -- Status Interface
         errorDet        => errorDet,
         locked          => gearboxAligned);

   ---------------
   -- 1:10 Gearbox
   ---------------
   U_Deserializer : entity surf.Gearbox
      generic map (
         TPD_G          => TPD_G,
         SLAVE_WIDTH_G  => 1,
         MASTER_WIDTH_G => 10)
      port map (
         -- Clock and Reset
         clk          => timingClk,
         rst          => timingRst,
         -- Slip Interface
         slip         => rxSlip,
         -- Slave Interface
         slaveData(0) => rx,
         -- Master Interface
         masterValid  => rxEncodeValid,
         masterData   => rxEncodeData);

   ----------------
   -- 8B10B Decoder
   ----------------
   U_Decode : entity surf.Decoder8b10b
      generic map (
         TPD_G       => TPD_G,
         NUM_BYTES_G => 1)
      port map (
         -- Clock and Reset
         clk         => timingClk,
         rst         => timingRst,
         -- Encoded Interface
         validIn     => rxEncodeValid,
         dataIn      => rxEncodeData,
         -- Encoded Interface
         validOut    => rxDecodeValid,
         dataOut     => rxDecodeData,
         dataKOut(0) => rxDecodeDataK,
         codeErr(0)  => rxCodeErr,
         dispErr(0)  => rxDispErr);

   -------------
   -- FSM Module
   -------------
   U_Fsm : entity surf.SugoiFpgaFsm
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => SIMULATION_G,
         TX_POLARITY_G   => TX_POLARITY_G,
         RX_POLARITY_G   => RX_POLARITY_G,
         NUM_ADDR_BITS_G => NUM_ADDR_BITS_G)
      port map (
         -- Clock and Reset
         clk             => timingClk,
         rst             => timingRst,
         -- Timing and Trigger Interface
         globalRst       => sugioGlobalRst,
         opCode          => sugioOpCode,
         -- RX Interface
         rxValid         => rxDecodeValid,
         rxData          => rxDecodeData,
         rxDataK         => rxDecodeDataK,
         -- TX Interface
         txStrobe        => txStrobe,
         txData          => txDecodeData,
         txDataK         => txDecodeDataK,
         -- Control/Monitoring
         disableClk      => disableClk,
         disableTx       => disableTx,
         polarityTx      => polarityTx,
         polarityRx      => polarityRx,
         enUsrDlyCfg     => enUsrDlyCfg,
         usrDlyCfg       => usrDlyCfg,
         bypFirstBerDet  => bypFirstBerDet,
         minEyeWidth     => minEyeWidth,
         lockingCntCfg   => lockingCntCfg,
         errorDet        => errorDet,
         gearboxAligned  => gearboxAligned,
         -- AXI-Lite Master Interface
         axilReadMaster  => readMaster,
         axilReadSlave   => readSlave,
         axilWriteMaster => writeMaster,
         axilWriteSlave  => writeSlave);

   ----------------
   -- 8B10B Encoder
   ----------------
   U_Encode : entity surf.Encoder8b10b
      generic map (
         TPD_G       => TPD_G,
         NUM_BYTES_G => 1)
      port map (
         -- Clock and Reset
         clk        => timingClk,
         rst        => timingRst,
         -- Decoded Interface
         validIn    => txStrobe,
         dataIn     => txDecodeData,
         dataKIn(0) => txDecodeDataK,
         -- Encoded Interface
         validOut   => txEncodeValid,
         dataOut    => txEncodeData);

   ---------------
   -- 10:1 Gearbox
   ---------------
   U_Serializer : entity surf.Gearbox
      generic map (
         TPD_G          => TPD_G,
         SLAVE_WIDTH_G  => 10,
         MASTER_WIDTH_G => 1)
      port map (
         -- Clock and Reset
         clk           => timingClk,
         rst           => timingRst,
         -- Slave Interface
         slaveValid    => txEncodeValid,
         slaveData     => txEncodeData,
         -- Master Interface
         masterData(0) => tx);

   --------------------------------------
   -- TX I/O Register + half cycle deskew
   --------------------------------------
   U_sugioTx : entity surf.OutputBufferReg
      generic map (
         TPD_G       => TPD_G,
         DIFF_PAIR_G => true)
      port map (
         I   => tx,
         C   => timingClk,
         SR  => disableTx,
         inv => polarityTx,
         dly => '1',                    -- deskew the data by half clock cycle
         O   => sugioTxP,
         OB  => sugioTxN);

   -------------------
   -- CLK I/O Register
   -------------------
   U_sugioClk : entity surf.ClkOutBufDiff
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G)
      port map (
         clkIn   => timingClk,
         rstIn   => disableClk,
         clkOutP => sugioClkP,
         clkOutN => sugioClkN);

end mapping;
