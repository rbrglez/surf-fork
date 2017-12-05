-------------------------------------------------------------------------------
-- File       : ClinkDual.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink control or data interface.
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
use work.ClinkPkg.all;
use work.AxiStreamPkg.all;
library unisim;
use unisim.vcomponents.all;

entity ClinkDual is
   generic (
      TPD_G              : time                  := 1 ns;
      UART_READY_EN_G    : boolean               := true;
      UART_AXIS_CONFIG_G : AxiStreamConfigType   := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Cable In/Out
      cblHalfP    : inout slv(4 downto 0); --  2,  4,  5,  6, 3
      cblHalfM    : inout slv(4 downto 0); -- 15, 17, 18, 19 16
      cblSerP     : out   sl; -- 20
      cblSerM     : out   sl; -- 7
      -- Delay clock and reset, 200Mhz
      dlyClk      : in  sl; 
      dlyRst      : in  sl; 
      -- System clock and reset, must be 100Mhz or greater
      sysClk      : in  sl;
      sysRst      : in  sl;
      -- Camera Control Bits
      camCtrl     : in  slv(3 downto 0);
      -- Config/status
      linkConfig  : in  ClLinkConfigType;
      linkStatus  : out ClLinkStatusType;
      chanConfig  : in  ClChanConfigType;
      -- Data output
      parData     : out slv(27 downto 0);
      parValid    : out sl;
      parReady    : in  sl := '1';
      -- UART data
      uartClk     : in  sl;
      uartRst     : in  sl;
      sUartMaster : in  AxiStreamMasterType;
      sUartSlave  : out AxiStreamSlaveType;
      sUartCtrl   : out AxiStreamCtrlType;
      mUartMaster : out AxiStreamMasterType;
      mUartSlave  : in  AxiStreamSlaveType);
end ClinkDual;

architecture rtl of ClinkDual is

   signal serRst     : sl;
   signal dataRst    : sl;
   signal cblOut     : slv(4 downto 0);
   signal cblIn      : slv(4 downto 0);
   signal tmpIn      : slv(4 downto 0);
   signal cblDirIn   : slv(4 downto 0);
   signal cblDirOut  : slv(4 downto 0);
   signal cblSerOut  : sl;

begin

   serRst  <= sysRst or (not chanConfig.enable);
   dataRst <= sysRst or chanConfig.enable;

   -------------------------------
   -- IO Buffers
   -------------------------------
   cblDirOut <= not cblDirIn;

   U_CableBuffGen : for i in 0 to 4 generate
--      U_CableBuff : IOBUFDS_DCIEN
--         generic map (
--            DIFF_TERM       => "TRUE",    -- Differential termination (TRUE/FALSE)
--            IBUF_LOW_PWR    => "FALSE",   -- Low Power - TRUE, HIGH Performance = FALSE
--            IOSTANDARD      => "LVDS_25", -- Specify the I/O standard
--            SLEW            => "FAST",    -- Specify the output slew rate
--            USE_IBUFDISABLE => "TRUE")    -- Use IBUFDISABLE function "TRUE" or "FALSE"
--         port map (
--            I    => cblOut(i),
--            O    => cblIn(i),
--            T    => cblDirIn(i),
--            IO   => cblHalfP(i),
--            IOB  => cblHalfM(i),
--            DCITERMDISABLE => cblDirOut(i),
--            IBUFDISABLE    => cblDirOut(i));

      U_CableBuff: IOBUFDS
         port map(
            I   => cblOut(i),
            O   => cblIn(i),
            T   => cblDirIn(i),
            IO  => cblHalfP(i),
            IOB => cblHalfM(i));

   end generate;

   U_SerOut: OBUFDS
      port map (
         I  => cblSerOut,
         O  => cblSerP,
         OB => cblSerM);

   -------------------------------
   -- Camera control bits
   -- Bits 1 & 3 inverted
   -------------------------------
   cblDirIn(2) <= not chanConfig.enable;
   cblOut(2)   <= camCtrl(0) when chanConfig.swCamCtrlEn(0) = '0' else chanConfig.swCamCtrl(0);

   cblDirIn(3) <= not chanConfig.enable;
   cblOut(3)   <= (not camCtrl(1)) when chanConfig.swCamCtrlEn(1) = '0' else (not chanConfig.swCamCtrl(1));

   cblDirIn(0) <= not chanConfig.enable;
   cblOut(0)   <= camCtrl(2) when chanConfig.swCamCtrlEn(2) = '0' else chanConfig.swCamCtrl(2);

   cblDirIn(4) <= not chanConfig.enable;
   cblOut(4)   <= (not camCtrl(3)) when chanConfig.swCamCtrlEn(3) = '0' else (not chanConfig.swCamCtrl(3));


   -------------------------------
   -- UART
   -------------------------------
   U_Uart: entity work.ClinkUart
      generic map (
         TPD_G              => TPD_G,
         UART_READY_EN_G    => UART_READY_EN_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         intClk        => dlyCLk,
         intRst        => dlyRst,
         baud          => chanConfig.serBaud,
         uartClk       => uartClk,
         uartRst       => uartRst,
         sUartMaster   => sUartMaster,
         sUartSlave    => sUartSlave,
         sUartCtrl     => sUartCtrl,
         mUartMaster   => mUartMaster,
         mUartSlave    => mUartSlave,
         rxIn          => cblIn(1),
         txOut         => cblSerOut);

   cblDirIn(1) <= '1';

   -------------------------------
   -- Data
   -------------------------------
   U_DeSerial : entity work.ClinkDeSerial
      generic map ( TPD_G => TPD_G )
      port map (
         cblIn      => cblIn,
         dlyClk     => dlyClk,
         dlyRst     => dlyRst,
         sysClk     => sysClk,
         sysRst     => dataRst,
         linkConfig => linkConfig,
         linkStatus => linkStatus,
         parData    => parData,
         parValid   => parValid,
         parReady   => parReady);

end architecture rtl;

