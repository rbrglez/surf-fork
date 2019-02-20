-------------------------------------------------------------------------------
-- File       : RoguePgp3Sim.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper on RogueStreamSim to simulate a PGPv3
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Pgp3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity RoguePgp3Sim is
   generic (
      TPD_G      : time                     := 1 ns;
      PORT_NUM_G : natural range 0 to 65535 := 1;
      NUM_VC_G   : integer range 1 to 16    := 4);
   port (
      -- GT Ports
      pgpRefClk       : in  sl;
      pgpGtRxP        : in  sl;
      pgpGtRxN        : in  sl;
      pgpGtTxP        : out sl                     := '0';
      pgpGtTxN        : out sl                     := '1';
      -- PGP Clock and Reset
      pgpClk          : out sl;
      pgpClkRst       : out sl;
      -- Non VC Rx Signals
      pgpRxIn         : in  Pgp3RxInType;
      pgpRxOut        : out Pgp3RxOutType;
      -- Non VC Tx Signals
      pgpTxIn         : in  Pgp3TxInType;
      pgpTxOut        : out Pgp3TxOutType;
      -- Frame Transmit Interface
      pgpTxMasters    : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface
      pgpRxMasters    : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxSlaves     : in  AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                     := '0';  -- Stable Clock
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_OK_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_OK_C);
end entity RoguePgp3Sim;

architecture sim of RoguePgp3Sim is

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal txOut : Pgp3TxOutType := PGP3_TX_OUT_INIT_C;
   signal rxOut : Pgp3RxOutType := PGP3_RX_OUT_INIT_C;

begin

   pgpClk    <= clk;
   pgpClkRst <= rst;

   pgpTxOut <= txOut;
   pgpRxOut <= rxOut;

   clk <= pgpRefClk;

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         DURATION_G     => 50)
      port map (
         clk    => clk,
         rstOut => rst);

   GEN_VEC : for i in NUM_VC_G-1 downto 0 generate
      U_PGP_VC : entity work.RogueTcpStreamWrap
         generic map (
            TPD_G               => TPD_G,
            PORT_NUM_G          => (PORT_NUM_G + i*2),
            SSI_EN_G            => true,
            CHAN_COUNT_G        => 1,
            COMMON_MASTER_CLK_G => true,
            COMMON_SLAVE_CLK_G  => true,
            AXIS_CONFIG_G       => PGP3_AXIS_CONFIG_C)
         port map (
            clk         => clk,              -- [in]
            rst         => rst,              -- [in]
            sAxisClk    => clk,              -- [in]
            sAxisRst    => rst,              -- [in]
            sAxisMaster => pgpTxMasters(i),  -- [in]
            sAxisSlave  => pgpTxSlaves(i),   -- [out]
            mAxisClk    => clk,              -- [in]
            mAxisRst    => rst,              -- [in]
            mAxisMaster => pgpRxMasters(i),  -- [out]
            mAxisSlave  => pgpRxSlaves(i));  -- [in]
   end generate GEN_VEC;

   txOut.phyTxActive <= '1';
   txOut.linkReady   <= '1';

   rxOut.phyRxActive    <= '1';
   rxOut.linkReady      <= '1';
   rxOut.remRxLinkReady <= '1';

end sim;
