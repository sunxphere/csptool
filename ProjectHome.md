This is a project to add functionality missing in the Chipscope Pro Analyzer GUI tool from Xilinx.


This tool auto-groups the individual bus bits into a single bus for Chipscope Pro Analyzer.

Features:
- Supports multiple FPGA devices and multiple ILA units per FPGA
- Supports Chipscope Pro v7.1.04i and v8.1.03i (Windows). Should work with other OS and/or other Chipscope versions too.

Usage:
- Create a new cpj projet with Chipscope Pro Analyzer (might not work if project is not 'fresh').
- Import the .cdc files to get relevant signal names.
- For each unit and each FPGA, make the waveform appear by clicking 'Waveform' in the left project tree.
- Save the project (you don't need to close Chipscope).
- Run the tool like this: perl csptool.pl your\_project.cpj
- Reload your Chipscope projet.

Misc
- It is suggested to compile this script into an .exe program. You can then associate .cpj files to csptool.exe, so that you can just double-click a .cpj file

