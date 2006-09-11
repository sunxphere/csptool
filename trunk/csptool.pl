# Copyright (c) 2006 Patrick Dubois, Telops inc.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of 
# this software and associated documentation files (the "Software"), to deal in 
# the Software without restriction, including without limitation the rights to 
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do 
# so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
# SOFTWARE.

# Todo:
# - Done. Group state machine style buses
# - Done. Support multiple ILA units per device.
# - Support token file to import multiple tokens in one file
# - Support files with buses already presents
# - Support files without waveform fields (i.e. freshly made projects)

use Tie::File;

if ( (@ARGV != 1)  or ($ARGV[0] eq '-h') or ($ARGV[0] eq 'h') or ($ARGV[0] eq 'help')) 
{
  die <<EOF;

 This tool auto-groups the individual bus bits into a single bus for Chipscope
 Pro Analyzer. 
 
 Features:
 - Supports multiple FPGA devices and multiple ILA units per FPGA
 - Supports Chipscope Pro v7.1.04i and v8.1.03i (Windows). Might 
   work with other OS and/or other Chipscope versions too.

 Usage:
 - Create a new cpj projet with Chipscope Pro Analyzer (might not work if project is not "fresh").
 - Import the .cdc files to get relevant signal names.
 - For each unit and each FPGA, make the waveform appear by clicking "Waveform" in the
   left project tree.
 - Save the project (you don't need to close Chipscope).
 - Run the tool like this: csptool your_project.cpj (I suggest to associate
   .cpj files to csptool.exe, so that you can just double-click a .cpj file)
 - Reload your Chipscope projet.

 Patrick Dubois
 pdubois@gel.ulaval.ca (Drop me an e-mail if you find this tool useful or have comments!)
 Quebec, Canada
 Version 1.1, September 2006
EOF
}

$filename = $ARGV[0];

open(INFILE,  ">>$filename") or die "Can't open $filename: $!";
close INFILE;

tie @filearray, 'Tie::File', $filename || die "Can't open: $!\n";

(tied @filearray)->defer; # Do all data manipulation in memory instead of directly on the file (MIGHT improve performance).


#-------------------------------------------------------------------------------
# First let's search for all the buses names and create a hash with them.
#-------------------------------------------------------------------------------
my %buses_hash;
my $line = 0;

for ($line=0; $line <= $#filearray; $line++)
{
   # Search for something like this:
   #
   # unit.1.0.waveform.posn.104.name=/U9/DDR_ADD<4>
   # or
   # unit.1.0.waveform.posn.100.name=/U9/avg_state_FFd2
   # or
   # unit.2.0.waveform.posn.181.name=/U26/Run_State_FFd11
   # or
   # unit.2.1.waveform.posn.180.name=/S1/U10/timeout<3>
   #
   if (  ( $filearray[$line] =~ /unit\.(\d)\.(\d)\.waveform\.posn\.(\d+)\.name=(\S+)<\d+>/ ) or
         ( $filearray[$line] =~ /unit\.(\d)\.(\d)\.waveform\.posn\.(\d+)\.name=(\S+\D+)\d+$/ ) )
   {
      my $device = $1;
      my $unit = $2;
      my $channel = $3;
      my $bus = $4;
      #print "$device $bus\n";
      push( @{ $units_hash{$device}{$unit}{$bus} }, $channel); # This creates a hash of hash of hashes (yeah, I'm dizzy too). 
   }

}
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Clean-up to remove single-bit buses
#-------------------------------------------------------------------------------
foreach my $device (keys %units_hash)
{  
   foreach my $unit (keys %{$units_hash{$device}})
   {     
      foreach my $bus ( keys %{$units_hash{$device}{$unit}} )
      {
         @channellist = @{ $units_hash{$device}{$unit}{$bus} } ;
         $nchannel = $#channellist;
         if ($nchannel == 0)
         {
            delete $units_hash{$device}{$unit}{$bus};
            #splice(@{ $units_hash{$device} }, $bus, 1);
         }
      }
   }
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Let's print out the content of each bus we found (for debug purposes)
#-------------------------------------------------------------------------------
foreach my $device (sort(keys %units_hash))
{
   foreach my $unit (sort (keys %{$units_hash{$device}}))
   {
      my @bus_array = keys %{$units_hash{$device}{$unit}} ; $nbus = $#bus_array + 1 ;
      print "Found $nbus new buses in Device $device, Unit $unit.\n";
#      foreach my $bus ( keys %{$units_hash{$device}{$unit}} )
#      {
#         print "Device $device, Unit $unit, $bus = @{ $units_hash{$device}{$unit}{$bus} }\n";
#      }
   }
}
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Let's add the buses in the signal declaration section of the cpj file
#-------------------------------------------------------------------------------
for ($line=0; $line <= $#filearray; $line++)
{
   # Search for something like this: unit.1.0.eventCount0
   if ( $filearray[$line] =~ /unit\.(\d)\.(\d).eventCount0/ )
   {     
      $device = $1;
      $unit = $2;
      print "Adding buses declarations to Device $device, Unit $unit ...\n";
      # First let's adjust this line to the right buscount:
      #
      # unit.1.0.port.-1.buscount=0
      #
      my @bus_array = keys %{$units_hash{$device}{$unit}} ; $nbus = $#bus_array + 1 ;
      #$nbus = scalar(keys(%HASH));
      #print "There are $nbus buses in device $device.\n";
      $filearray[$line+1] = "unit.$device.$unit.port.-1.buscount=$nbus";

      # Let's insert something like that (after the line we found):
      #
      # unit.1.0.port.-1.b.0.alias=/U14/TX_DATA
      # unit.1.0.port.-1.b.0.channellist=22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45
      # unit.1.0.port.-1.b.0.name=/U14/TX_DATA
      #
      $b = 0;
      foreach my $bus ( keys %{$units_hash{$device}{$unit}} )
      {
         #print "Bus name: $bus\n";
         @channellist = @{ $units_hash{$device}{$unit}{$bus} } ;
         @channellist = sort { $a <=> $b } (@channellist); # Sort the channel list
         $new = "unit.$device.$unit.port.-1.b.$b.alias=$bus\nunit.$device.$unit.port.-1.b.$b.channellist=@channellist\nunit.$device.$unit.port.-1.b.$b.name=$bus";
         splice @filearray, $line+1, 0, $new;
         $b++;
      }
   }
}
#-------------------------------------------------------------------------------

# Delete all values of the hash, not needed anymore (but keep the hash structure).
foreach my $device (keys %units_hash)
{  
   foreach my $unit (keys %{$units_hash{$device}})
   {
      foreach my $bus ( keys %{$units_hash{$device}{$unit}} )
      {
         @{ $units_hash{$device}{$bus} } = ();
      }
   }
}


#-------------------------------------------------------------------------------
# Now let's delete the individual bus bits from the waveform.
# Replace the first occurence of a bus bit by the full bus.
#-------------------------------------------------------------------------------

# We are looking for something like this:
#
# unit.1.0.waveform.posn.0.channel=0
# unit.1.0.waveform.posn.0.name=/MODE<0>
# unit.1.0.waveform.posn.0.type=signal
# unit.1.0.waveform.posn.1.channel=1
# unit.1.0.waveform.posn.1.name=/MODE<1>
# unit.1.0.waveform.posn.1.type=signal
#
# At the first occurence of the bus name, we store its position (posn.0) and we
# replace it with the full bus. We then delete each subsequent bus appearance.

#$first_occurance = 1;
#print "Processing device $device, $bus ...\n";
print "Reformatting the waveform section of the cpj file ...\n";
for ($line=0; $line <= $#filearray; $line++)
{        
   # Search for something like this: 
   #
   # unit.1.0.waveform.posn.0.name=/MODE<0>
   # or
   # unit.1.0.waveform.posn.86.name=/U14/TX_DATA<6>
   # or 
   # unit.1.0.waveform.posn.100.name=/U9/avg_state_FFd2
   # or
   # unit.1.0.waveform.posn.100.name=/U9/avg_state_FFd21
   #
   if ( $filearray[$line] =~ /unit\.(\d)\.(\d)\.waveform\.posn\.(\d+)\.name=(\S+)<\d+>/ )         
   {
      my $linedevice = $1;
      my $lineunit = $2;
      my $posn = $3;
      my $linebus = $4;    
      # Now let's see if this bus is in the hash (it should be, unless the bus is single bit)      
      @buslist = keys %{$units_hash{$linedevice}{$lineunit}} ;     
      foreach my $bus (@buslist)
      {
         if ($bus =~ /^$linebus$/ )
         {
            if ($units_hash{$linedevice}{$lineunit}{$linebus} == 1)
            {
               # Delete current line, as well as the line above and the line under.
               delete($filearray[$line-1]);
               delete($filearray[$line]);
               delete($filearray[$line+1]);  
            }
            else # first occurance
            {
               $units_hash{$linedevice}{$lineunit}{$linebus} = 1;
               $filearray[$line] =~ s/<\d+>//;        # Delete the <xx> part of the name
               $filearray[$line+1] =~ s/signal/bus/;  # Replace signal by bus 
               # Add decimal bus radix line
               #$new = "unit.$device.0.waveform.posn.$posn.radix=4";
               #splice @filearray, $line+2, 0, $new;
               
            }  
            
         }
      }
   }
   elsif ( $filearray[$line] =~ /unit\.(\d)\.0\.waveform\.posn\.(\d+)\.name=(\S+\D+)\d+$/ )
   {
      my $linedevice = $1;
      my $lineunit = $2;
      my $posn = $3;
      my $linebus = $4;    
      # Now let's see if this bus is in the hash (it should be, unless the bus is single bit)      
      @buslist = keys %{$units_hash{$linedevice}{$lineunit}} ;     
      foreach my $bus (@buslist)
      {
         if ($bus =~ /^$linebus$/ )
         {
            if ($units_hash{$linedevice}{$lineunit}{$linebus} == 1)
            {
               # Delete current line, as well as the line above and the line under.
               delete($filearray[$line-1]);
               delete($filearray[$line]);
               delete($filearray[$line+1]);  
            }
            else # first occurance
            {
               $units_hash{$linedevice}{$lineunit}{$linebus} = 1;
               $filearray[$line] =~ s/\d+$//;         # Delete the 123 part of the name
               $filearray[$line+1] =~ s/signal/bus/;  # Replace signal by bus 
               # Add decimal bus radix line
               #$new = "unit.$device.0.waveform.posn.$posn.radix=4";
               #splice @filearray, $line+2, 0, $new;
               
            }  
            
         }
      }     
   }
}



#-------------------------------------------------------------------------------

(tied @filearray)->flush; # Write all changes to the file.
untie @filearray;

print "\nAll done.\n\n";
