#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

import surf.protocols.coaxpress as coaxpress

class PhantomS991(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(coaxpress.Bootstrap(
            offset = 0x0000_0000,
            expand = False,
        ))

        #############################################################
        # Start of manufacturer-specific register space at 0x00006000
        #############################################################

        self.add(pr.RemoteVariable(
            name         = 'DevicePhfwVersionReg',
            description  = 'Version of the firmware in the device.',
            base         = pr.UIntBE,
            offset       = 0x8174,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceSerialNumberReg',
            description  = 'Serial Number of device.',
            base         = pr.UIntBE,
            offset       = 0x8158,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceIPAddress',
            description  = 'Category for Device information and control.',
            base         = pr.String,
            offset       = 0x8300,
            bitSize      = 8*32,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceNetmask',
            description  = 'Category for Device information and control.',
            base         = pr.String,
            offset       = 0x8320,
            bitSize      = 8*32,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pDeviceTemperatureSelectorReg',
            description  = 'Selects the location within the device, where the temperature will be measured.',
            base         = pr.UIntBE,
            offset       = 0x8168,
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pDeviceTemperatureReg',
            description  = 'Device temperature in degrees Celsius (C).',
            base         = pr.UIntBE,
            offset       = 0x8168,
            bitSize      = 16,
            bitOffset    = 16,
            mode         = 'RO',
            units        = 'degC',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WidthMaxReg',
            description  = 'Maximum width (in pixels) of the image. The dimension is calculated after horizontal binning, decimation or any other function changing the horizontal dimension of the image.',
            base         = pr.UIntBE,
            offset       = 0x8010,
            mode         = 'RO',
            units        = 'pixels',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WidthReg',
            description  = 'This feature represents the actual image width expelled by the camera (in pixels).',
            base         = pr.UIntBE,
            offset       = 0x8000,
            mode         = 'RW',
            units        = 'pixels',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeightMaxReg',
            description  = 'Maximum height (in pixels) of the image. This dimension is calculated after vertical binning, decimation or any other function changing the vertical dimension of the image.',
            base         = pr.UIntBE,
            offset       = 0x8014,
            mode         = 'RO',
            units        = 'pixels',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeightReg',
            description  = 'This feature represents the actual image height expelled by the camera (in pixels).',
            base         = pr.UIntBE,
            offset       = 0x8004,
            mode         = 'RW',
            units        = 'pixels',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PixelFormatReg',
            description  = 'This feature indicates the format of the pixel to use during the acquisition.',
            base         = pr.UIntBE,
            offset       = 0x8008,
            mode         = 'RW',
            enum         = {
                0x00000000: 'Undefined',
                0x01080001: 'Mono8',
                0x010C0006: 'Mono12',
                0x01100007: 'Mono16',
                0x0108000A: 'BayerGB8',
                0x010C0055: 'BayerGB12',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ImageSourceReg',
            description  = 'This feature controls the image source.',
            base         = pr.UIntBE,
            offset       = 0x8120,
            mode         = 'RW',
            enum        = {
                0: 'imgsrc0',
                1: 'imgsrc1',
                2: 'imgsrc2',
                3: 'imgsrc3',
                4: 'imgsrc4',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ImageSourceGrabReg',
            description  = 'Grab Gain and Offset from camera.',
            base         = pr.UIntBE,
            offset       = 0x8124,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquisitionModeReg',
            description  = 'This feature controls the acquisition mode of the device.',
            base         = pr.UIntBE,
            offset       = 0x8018,
            mode         = 'RW',
            enum         = {
                0: 'undefined',
                2: 'Continuous',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquisitionStartReg',
            description  = 'This feature starts the Acquisition of the device.',
            base         = pr.UIntBE,
            offset       = 0x801C,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquisitionStopReg',
            description  = 'This feature stops the Acquisition of the device at the end of the current Frame.',
            base         = pr.UIntBE,
            offset       = 0x8020,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pFrameRateReg',
            description  = 'Frame rate in Hz.',
            base         = pr.FloatBE,
            offset       = 0x80C0,
            mode         = 'RW',
            units        = 'Hz',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pFrameRateRegMax',
            description  = 'Frame rate in Hz.',
            base         = pr.FloatBE,
            offset       = 0x80C4,
            mode         = 'RO',
            units        = 'Hz',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExposureTimeReg',
            description  = 'Sets the Exposure time (in microseconds). This controls the duration where the photosensitive cells are exposed to light.',
            base         = pr.FloatBE,
            offset       = 0x80C8,
            mode         = 'RW',
            units        = 'microseconds',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pExposureTimeRegMax',
            description  = 'Sets the Exposure time (in microseconds). This controls the duration where the photosensitive cells are exposed to light.',
            base         = pr.FloatBE,
            offset       = 0x80CC,
            mode         = 'RO',
            units        = 'microseconds',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SensorShutterModeReg',
            description  = 'Select Global or Rolling shutter mode.',
            base         = pr.UIntBE,
            offset       = 0x817C,
            mode         = 'RW',
            enum         = {
                0: 'Rolling',
                1: 'Global',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'FeaturesReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x80EC,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TriggerModeReg',
            description  = 'Select camera sync mode.',
            base         = pr.UIntBE,
            offset       = 0x8128,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RW',
            enum         = {
                0: 'TriggerModeOff',
                1: 'TriggerModeOn',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TriggerSelectorReg',
            description  = 'Selects the type of trigger to configure.',
            base         = pr.UIntBE,
            offset       = 0x8128,
            bitSize      = 8,
            bitOffset    = 16,
            mode         = 'RW',
            enum         = {
                0: 'ExposureStart',
                1: 'ExposureActive',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TriggerSourceReg',
            description  = 'Specifies the internal signal or physical input Line to use as the trigger source. The selected trigger must have its TriggerMode set to On.',
            base         = pr.UIntBE,
            offset       = 0x8128,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RW',
            enum         = {
                0: 'GPIO0',
                1: 'GPIO1',
                2: 'GPIO2',
                5: 'SWTRIGGER',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRLReg_fan',
            description  = 'Turn camera fan on/off.',
            base         = pr.UIntBE,
            offset       = 0x8180,
            bitSize      = 8,
            bitOffset    = 16,
            mode         = 'RW',
            enum         = {
                0: 'FanOff',
                1: 'FanOn',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRLReg_led',
            description  = 'Turn CXP LEDs on/off.',
            base         = pr.UIntBE,
            offset       = 0x8180,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RW',
            enum         = {
                0: 'LEDOff',
                1: 'LEDOn',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TimeStampSetReg',
            description  = 'Set camera time by entering current time in seconds since January 1st, 1970.',
            base         = pr.UIntBE,
            offset       = 0x8188,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensApertureReg',
            description  = 'Lens Aperture.',
            base         = pr.UIntBE,
            offset       = 0x81A0,
            mode         = 'RW',
            enum         = {
                0: 'undefined',
                10: 'f10',
                12: 'f12',
                14: 'f14',
                18: 'f18',
                20: 'f20',
                24: 'f24',
                28: 'f28',
                33: 'f33',
                40: 'f40',
                48: 'f48',
                56: 'f56',
                67: 'f67',
                80: 'f80',
                96: 'f96',
                110: 'f110',
                132: 'f132',
                160: 'f160',
                192: 'f192',
                220: 'f220',
                264: 'f264',
                320: 'f320',
                384: 'f384',
                480: 'f480',
                576: 'f576',
                640: 'f640',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensApertureMinReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x81A4,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensApertureMaxReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x81A8,
            mode         = 'RO',
        ))


        self.add(pr.RemoteVariable(
            name         = 'LensFocusReg',
            description  = 'Set Lens Focus',
            base         = pr.UIntBE,
            offset       = 0x81AC,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensFocusStepReg',
            description  = 'Set Lens Focus Step',
            base         = pr.UIntBE,
            offset       = 0x81B0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensShutterReg',
            description  = 'Camera Shutter Open/Close',
            base         = pr.UIntBE,
            offset       = 0x81B4,
            mode         = 'RW',
            enum         = {
                0: 'Open',
                1: 'Close',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'GainSelectorReg',
            description  = 'Selects which Gain is controlled by the various Gain features',
            base         = pr.UIntBE,
            offset       = 0x80E4,
            mode         = 'RW',
            enum         = {
                0: 'undefined',
                20: 'DigitalAll',
                21: 'DigitalRed',
                22: 'DigitalGreen',
                23: 'DigitalBlue',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'GainReg',
            description  = 'Controls the selected gain as an absolute physical value. This is an amplification factor applied to the video signal.',
            base         = pr.FloatBE,
            offset       = 0x80E8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BlackLevelSelectorReg',
            description  = 'Selects which Black Level is controlled by the various Black Level features.',
            base         = pr.UIntBE,
            offset       = 0x80F8,
            mode         = 'RW',
            enum         = {
                0: 'All',
                1: 'Red',
                2: 'Green',
                3: 'Blue',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'BlackLevelReg',
            description  = 'Controls the analog black level as an absolute physical value. This represents a DC offset applied to the video signal.',
            base         = pr.FloatBE,
            offset       = 0x80FC,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BalanceWhiteAutoReg',
            description  = 'Controls the mode for automatic white balancing between the color channels.',
            base         = pr.UIntBE,
            offset       = 0x80DC,
            mode         = 'RW',
            enum         = {
                0: 'Off',
                1: 'Once',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'BalanceWhiteMarkerReg',
            description  = 'Auto White Balance Marker.',
            base         = pr.UIntBE,
            offset       = 0x80E0,
            mode         = 'RW',
            enum         = {
                0: 'Off',
                1: 'Once',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'GainBlackLevelResetReg',
            description  = 'Set camera gain and black level to default.',
            base         = pr.UIntBE,
            offset       = 0x8208,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'OutputRawImageReg',
            description  = 'Grab raw images',
            base         = pr.UIntBE,
            offset       = 0x820C,
            mode         = 'RW',
            enum         = {
                0: 'Off',
                1: 'Once',
            },
        ))

        for i in range(3):
            self.add(pr.RemoteVariable(
                name         = f'DigitalIOReg[{i}]',
                description  = 'Selects the physical line (or pin) of the external device connector or the virtual line of the Transport Layer to configure.',
                base         = pr.UIntBE,
                offset       = 0x8198,
                bitSize      = 8,
                bitOffset    = 24-(i*8),
                mode         = 'RW',
                enum         = {
                    0:  'eventin',
                    3:  'memgate',
                    6:  'userin',
                    16: 'strobe',
                    17: 'triggerout',
                    18: 'ready',
                    21: 'swtrigger',
                    22: 'tcout',
                    31: 'userout',
                },
            ))

        self.add(pr.RemoteVariable(
            name         = 'UserOutputSetReg',
            description  = 'Set user output high/low.',
            base         = pr.UIntBE,
            offset       = 0x8200,
            mode         = 'RW',
            enum         = {
                0: 'Low',
                1: 'High',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'UserInputStatusReg',
            description  = 'Displays state of user input GPIO line.',
            base         = pr.UIntBE,
            offset       = 0x8204,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkNumberReg',
            description  = 'Bootstrap register Banks.',
            base         = pr.UIntBE,
            offset       = 0x8184,
            mode         = 'RW',
            enum         = {
                0: 'Banks_A',
                1: 'Banks_AB',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConnectedBankIDReg',
            description  = 'Image1StreamID.',
            base         = pr.UIntBE,
            offset       = 0x80D8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'EventRefreshReg',
            description  = 'EventRefresh',
            base         = pr.UIntBE,
            offset       = 0x827C,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceTapGeometryReg',
            description  = 'This device tap geometry feature describes the geometrical properties characterizing the taps of a camera as presented at the output of the device.',
            base         = pr.UIntBE,
            offset       = 0x800C,
            mode         = 'RW',
            enum         = {
                0: 'Geometry_1X_1Y',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'UserSerialTxReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x8148,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'UserSerialRxReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x8154,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'UserSerialBaudRateReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x8164,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'FactorySerialTxReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x8140,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'FactorySerialRxReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x8144,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'FactorySerialUpdateReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x8130,
            mode         = 'RW',
        ))
