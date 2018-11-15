-------------------------------------------------------------------------------
-- File       : AxiRssiCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for RSSI + AXIS packetizer 
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.AxiRssiPkg.all;
use work.SsiPkg.all;

entity AxiRssiCoreWrapper is
   generic (
      TPD_G                : time                 := 1 ns;
      SERVER_G             : boolean              := true;  -- Module is server or client 
      JUMBO_G              : boolean              := false;
      AXI_CONFIG_G         : AxiConfigType        := RSSI_AXI_CONFIG_G;
      -- AXIS Configurations
      APP_STREAMS_G        : positive             := 1;
      APP_STREAM_ROUTES_G  : Slv8Array            := (0 => "--------");
      ILEAVE_ON_NOTVALID_G : boolean              := false;
      APP_AXIS_CONFIG_G    : AxiStreamConfigArray := (0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C));
      TSP_AXIS_CONFIG_G    : AxiStreamConfigType  := ssiAxiStreamConfig(16, TKEEP_NORMAL_C);
      -- RSSI Timeouts
      CLK_FREQUENCY_G      : real                 := 156.25E+6;  -- In units of Hz
      TIMEOUT_UNIT_G       : real                 := 1.0E-3;  -- In units of seconds
      ACK_TOUT_G           : positive             := 25;  -- unit depends on TIMEOUT_UNIT_G 
      RETRANS_TOUT_G       : positive             := 50;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= MAX_NUM_OUTS_SEG_G*Data segment transmission time)
      NULL_TOUT_G          : positive             := 200;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= 4*RETRANS_TOUT_G)
      -- Counters
      MAX_RETRANS_CNT_G    : positive             := 8;
      MAX_CUM_ACK_CNT_G    : positive             := 3);
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl;
      -- AXI Segment Buffer Interface
      axiOffset       : in  slv(63 downto 0) := (others=>'0');
      mAxiWriteMaster : out AxiWriteMasterType;
      mAxiWriteSlave  : in  AxiWriteSlaveType;
      mAxiReadMaster  : out AxiReadMasterType;
      mAxiReadSlave   : in  AxiReadSlaveType;      
      -- SSI Application side
      sAppAxisMasters : in  AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
      sAppAxisSlaves  : out AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);
      mAppAxisMasters : out AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
      mAppAxisSlaves  : in  AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);
      -- SSI Transport side
      sTspAxisMaster  : in  AxiStreamMasterType;
      sTspAxisSlave   : out AxiStreamSlaveType;
      mTspAxisMaster  : out AxiStreamMasterType;
      mTspAxisSlave   : in  AxiStreamSlaveType;
      -- High level  Application side interface
      openRq          : in  sl                     := '0';
      closeRq         : in  sl                     := '0';
      inject          : in  sl                     := '0';
      -- AXI-Lite Register Interface
      sAxilReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      sAxilReadSlave     : out AxiLiteReadSlaveType;
      sAxilWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      sAxilWriteSlave    : out AxiLiteWriteSlaveType;
      -- Internal statuses
      statusReg         : out slv(6 downto 0));
end entity AxiRssiCoreWrapper;

architecture mapping of AxiRssiCoreWrapper is

   constant PACKETIZER_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant MAX_SEG_SIZE_C     : positive := ite(JUMBO_G,4096,1024); -- Using 4kB as jumbo to make the AXI FSM logic simpler
   constant MAX_SEGS_BITS_C    : positive := bitSize(MAX_SEG_SIZE_C);
   
   signal maxSegs  : slv(MAX_SEGS_BITS_C-1 downto 0);   
   signal maxObSegSize     : slv(15 downto 0);

   signal status           : slv(6 downto 0);
   signal rssiNotConnected : sl;
   signal rssiConnected    : sl;

   signal rxMasters : AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
   signal rxSlaves  : AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);

   signal depacketizerMasters : AxiStreamMasterArray(1 downto 0);
   signal depacketizerSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal packetizerMasters : AxiStreamMasterArray(1 downto 0);
   signal packetizerSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal txMasters : AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);
   
begin

   maxSegs <= ite(unsigned(maxObSegSize) >= MAX_SEG_SIZE_C,slv(to_unsigned(MAX_SEG_SIZE_C, maxSegs'length)),maxObSegSize(maxSegs'range));
   
   statusReg        <= status;
   rssiConnected    <= status(0);
   rssiNotConnected <= not(rssiConnected);   

   GEN_RX :
   for i in (APP_STREAMS_G-1) downto 0 generate
      U_Rx : entity work.AxiStreamResize
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            READY_EN_G          => true,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => APP_AXIS_CONFIG_G(i),
            MASTER_AXI_CONFIG_G => PACKETIZER_AXIS_CONFIG_C)
         port map (
            -- Clock and reset
            axisClk     => clk,
            axisRst     => rst,
            -- Slave Port
            sAxisMaster => sAppAxisMasters_i(i),
            sAxisSlave  => sAppAxisSlaves_o(i),
            -- Master Port
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));
   end generate GEN_RX;

   U_AxiStreamMux : entity work.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => APP_STREAMS_G,
         MODE_G               => "ROUTED",
         TDEST_ROUTES_G       => APP_STREAM_ROUTES_G,
         ILEAVE_EN_G          => true,
         ILEAVE_ON_NOTVALID_G => ILEAVE_ON_NOTVALID_G,
         ILEAVE_REARB_G       => (MAX_SEG_SIZE_C/PACKETIZER_AXIS_CONFIG_C.TDATA_BYTES_C),
         PIPE_STAGES_G        => 1)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMasters => rxMasters,
         sAxisSlaves  => rxSlaves,
         -- Master
         mAxisMaster  => packetizerMasters(0),
         mAxisSlave   => packetizerSlaves(0));

   U_Packetizer : entity work.AxiStreamPacketizer2
      generic map (
         TPD_G                => TPD_G,
         BRAM_EN_G            => true,
         CRC_MODE_G           => "FULL",
         CRC_POLY_G           => x"04C11DB7",
         TDEST_BITS_G         => 8,
         MAX_PACKET_BYTES_G   => MAX_SEG_SIZE_C,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         maxPktBytes => maxSegs,
         sAxisMaster => packetizerMasters(0),
         sAxisSlave  => packetizerSlaves(0),
         mAxisMaster => packetizerMasters(1),
         mAxisSlave  => packetizerSlaves(1));
         
   U_RssiCore : entity work.AxiRssiCore
      generic map (
         TPD_G               => TPD_G,
         SERVER_G            => SERVER_G,
         -- AXIS Configurations
         APP_AXIS_CONFIG_G   => PACKETIZER_AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G   => TSP_AXIS_CONFIG_G,
         -- Window parameters of receiver module
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_C,
         MAX_NUM_OUTS_SEG_G  => (2**WINDOW_ADDR_SIZE_C),
         MAX_SEG_SIZE_G      => MAX_SEG_SIZE_C,
         SEGMENT_ADDR_SIZE_G => bitSize(MAX_SEG_SIZE_C/8),
         -- RSSI Timeouts
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         ACK_TOUT_G          => ACK_TOUT_G,
         NULL_TOUT_G         => NULL_TOUT_G,
         -- Counters
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G   => MAX_CUM_ACK_CNT_G)
      port map (
         -- Clock and Reset
         clk            => clk,
         rst            => rst,
         -- AXI Segment Buffer Interface
         axiOffset       => axiOffset,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave,
         mAxiReadMaster  => mAxiReadMaster,
         mAxiReadSlave   => mAxiReadSlave,
         -- SSI Application side
         sAppAxisMaster => packetizerMasters(1),
         sAppAxisSlave  => packetizerSlaves(1),
         mAppAxisMaster => depacketizerMasters(1),
         mAppAxisSlave  => depacketizerSlaves(1),
         -- SSI Transport side
         sTspAxisMaster  => sTspAxisMaster,
         sTspAxisSlave   => sTspAxisSlave,
         mTspAxisMaster  => mTspAxisMaster,
         mTspAxisSlave   => mTspAxisSlave,
         -- High level  Application side interface
         openRq         => openRq,
         closeRq        => closeRq,
         inject         => inject,
         -- AXI-Lite Register Interface
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave,
         -- Internal statuses
         statusReg      => statusReg,
         maxSegSize     => maxObSegSize);
         
   U_Depacketizer : entity work.AxiStreamDepacketizer2
      generic map (
         TPD_G                => TPD_G,
         BRAM_EN_G            => true,
         CRC_MODE_G           => "FULL",
         CRC_POLY_G           => x"04C11DB7",
         TDEST_BITS_G         => 8,
         INPUT_PIPE_STAGES_G  => 0,  -- No need for input stage, RSSI output is already pipelined
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         linkGood    => rssiConnected,
         sAxisMaster => depacketizerMasters(1),
         sAxisSlave  => depacketizerSlaves(1),
         mAxisMaster => depacketizerMasters(0),
         mAxisSlave  => depacketizerSlaves(0));

   U_AxiStreamDeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         PIPE_STAGES_G  => 1,
         NUM_MASTERS_G  => APP_STREAMS_G,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => APP_STREAM_ROUTES_G)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMaster  => depacketizerMasters(0),
         sAxisSlave   => depacketizerSlaves(0),
         -- Master
         mAxisMasters => txMasters,
         mAxisSlaves  => txSlaves);

   GEN_TX :
   for i in (APP_STREAMS_G-1) downto 0 generate
      U_Tx : entity work.AxiStreamResize
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            READY_EN_G          => true,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => PACKETIZER_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => APP_AXIS_CONFIG_G(i))
         port map (
            -- Clock and reset
            axisClk     => clk,
            axisRst     => rst,
            -- Slave Port
            sAxisMaster => txMasters(i),
            sAxisSlave  => txSlaves(i),
            -- Master Port
            mAxisMaster => mAppAxisMasters(i),
            mAxisSlave  => mAppAxisSlaves(i));
   end generate GEN_TX;

end architecture mapping;
