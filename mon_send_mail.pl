#!/usr/bin/perl -w 
#
# Nagios addon to send messages as text and html
#
# This plugin is a forked by Martin Fuerstenau (martin.fuerstenau@oce.com from the original one 
# nagios_send_service_mail.pl written by Frank Migge (support at frank4dd dot com)
# and Robert Brecht published May 20, 2015, (c)2012 Frank Migge
# 
# License: GPL
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# History and Changes:
#
# - 12 Mar 2017 M.Fuerstenau
#   - Started with actual version 1.8
#   - Removed all "unnecessary" stuff
#     - Removed sending graphs for pnp4nagios
#     - Removed sending graphs for nagiosgraph
#     - Removed support for hostgroups
#     - Removed support for servicegroups
#     - Removed support for cc and bcc (doesn't make sense).
#     - Removed debug and test function. Not necessary.
#     - Removed supporting languages. English hard coded
#     - Removed using supporting languages. English hard coded
#     - Removed create_address() using supporting languages. English hard coded
#
#   - Changed
#     - Changed from global variables to "my", because using this 
#       the purpose of the variables can be documented better.
#     - Reformatted code for better readability
#     - Simplified variable names.
#     - Changed from sending either HTML mail or text mail to a multipart mail
#       containing both
#     - Changedusing environment variables for handing over nagios macros ($SERVICESDESC$) etc..
#       THIS IS IMPORTANT BECAUSE USING THE VARIABLES CAN CAUSE PERFORMANCE ISSUES
#       IN NAGIOS. Therefore this should be disabled in Nagios. With every run of a plugin
#       the whole environment is exported to the plugin. Nightmare. All parameters will now
#       be submitted using command line options.
#
#   - Added
#     - Option -t. This tells for the link to the monitor systeme whether Thruk
#       will be used or the classical interface.
#     - Added filtering out HTML code from service output for text mails
#     - Added replaceing new line by <br> for  HTML mails
#
# - 14 Nov 2017 M.Fuerstenau
#   - Added
#     - Moved all definitions users can adopt to seperate configuration file


use Getopt::Long;
use Mail::Sendmail;
use Digest::MD5 qw(md5_hex);
use MIME::Base64;
use File::Temp;
use File::Basename;
use warnings;

####### Global Variables - No changes necessary below this line ##########

my $ProgVersion ='2.0.0';                                     # The version of this script

my $logo_id;
my $logo_img;                                                 # base64-encoded logo
my $logo_type;                                                # Logo image file format (jpg, gif, or png)
my $notificationtype = 'PROBLEM';                                         # Nagios notification type, i.e. PROBLEM
my $notificationauthor;                                       # Nagios notification author (if avail.)
my $notificationcmt;                                          # Nagios notification comment (if avail.)
my $servicedesc;                                              # Nagios service description
my $servicedispname;                                          # Nagios service display name
my $state = 'PING';                                                    # Nagios host or service state
my $hostname = 'Nagios Monitoring';                           # Nagios monitored host name
my $hostalias;                                                # Nagios monitored host alias
my $hostaddress = '13.250.56.146';                            # Nagios monitored host IP address
my $serviceoutput;                                            # Nagios service check output data
my $longserviceoutput;                                        # Nagios long service check output data
my $datetime;                                                 # Nagios date when the event was recorded
my $recipients = 'fazrul@softsolvers.com';                                               # The recipients defined in $CONTACTEMAIL$

my $help;                                                     # We want help
my $version;                                                  # Print version

my $NagURL;                                                   # Contains basics for linking to Nagios GUI
my $NagURL_status;                                            # Contains link to Nagios GUI URLs for HTML
                                                              # emails for host with all services (status)
my $NagURL_extinfo;                                           # Contains link to Nagios GUI URLs for HTML
                                                              # emails for detailed host/service info
my $NagHost = 'http://13.250.56.146/nagios/';                 # Name of the monitor host
                                                              # (i.e. monitor.mydomain.net)
                                                              
my $thruk;                                                    # Flag whether the Nagios GUI is Thrul of classic.
my $ssl;                                                      # HTTP or HTTPS?

my $text_msg;                                                 # The plaintext notification
my $html_msg;                                                 # The HTML-formatted notification
my $boundary1;                                                # Unique string for multi-part emails
my $boundary2;                                                # Unique string for multi-part emails

my $config_file;                                              # Will store the name of the configuration file
my %mail;

# $empty_img is a base64-encoded, white 1x1 pixel gif image, we
# use it if the logo or the Nagiosgraph data cannot be found.
my $empty_img = "R0lGODlhAQABAJEAAAAAAP///////wAAACH5BAEAAAIALAAAAAABAAEAAAICTAEAOw==";



########################################################################
# main
########################################################################
$smtphost = "s13852.securessl.net";
Getopt::Long::Configure ("bundling");
GetOptions(
          'V'   => \$version,           'version'               => \$version,
          'v'   => \$version,
          'h'   => \$help,              'help'                  => \$help,
          't'   => \$thruk,             'thruk'                 => \$thruk,
          's'   => \$ssl,               'ssl'                   => \$ssl,
          'c:s' => \$config_file,       'configuration:s'       => \$config_file,
          'N:s' => \$NagHost,           'nagios:s'              => \$NagHost,
          'S:s' => \$smtphost,          'smtphost:s'            => \$smtphost,
          'r:s' => \$recipients,        'recipients:s'          => \$recipients,
                                        'notificationtype:s'    => \$notificationtype,
                                        'datetime:s'            => \$datetime,
                                        'hostaddress:s'         => \$hostaddress,
                                        'hostalias:s'           => \$hostalias,
                                        'hostname:s'            => \$hostname,
                                        'notificationauthor:s'  => \$notificationauthor,
                                        'notificationcmt:s'     => \$notificationcmt,
                                        'servicedesc:s'         => \$servicedesc,
                                        'servicedispname:s'     => \$servicedispname,
                                        'serviceoutput:s'       => \$serviceoutput,
                                        'longserviceoutput:s'   => \$longserviceoutput,
                                        'state:s'               => \$state) or unknown_arg();


# Creating the name of the config file
if (!defined ($config_file))
   {
   $config_file  = dirname("$0",  ".pl") . "/" . basename("$0",  ".pl") . ".cfg";
   }

# Processing the config file

if (-e $config_file)
   {
   if (-z $config_file)
      {
      print "Configuration file $config_file is empty.\n";
      exit 2;
      }
   if (!-f $config_file)
      {
      print "Configuration file $config_file is not a plain file.\n";
      exit 2;
      }
   do "$config_file";
   }
else
   {
   print "Configuration file $config_file not found.\n";
   exit 2;
   }


# Basic checks
if (defined ($help))
   {
   help();
   exit 0;
   }

if (defined($version))
   {
   print_version();
   exit 0;
   }

if (!defined($NagHost))
   {
   print "Error: No monitor host given.\n";
   print_usage();
   exit 2;
   }
else
   {
   $NagURL = $NagHost;
   }

if (!defined($ssl))
   {
   $NagURL = "http://$NagURL/";
   }
else
   {
   $NagURL = "https://$NagURL/";
   }

if (!defined($recipients))
   {
   print "Error: No recipients have been provided.\n";
   print_usage();
   exit 2;
   }
else
   {
   %mail = ( To     => $recipients,
             From   => $mail_sender,
             Sender => $mail_sender );
   }

if (!defined ($datetime))
   {
   print_version();
   print "\nError, No date/time for event provided.\n";
   print_usage();
   exit 2;
   }

if (!defined ($notificationtype))
   {
   print_version();
   print "\nError, No notification type available.\n";
   print_usage();
   exit 2;
   }

if (!defined ($hostaddress))
   {
   print_version();
   print "\nError, No host address given.\n";
   print_usage();
   exit 2;
   }

if (!defined ($hostname))
   {
   print_version();
   print "\nError, No host name given.\n";
   print_usage();
   exit 2;
   }

if (defined($servicedesc))
   {
   if (!defined($serviceoutput))
      {
      print "Error: No service output provided.\n";
      print_usage();
      exit 2;
      }
   if (!defined($state))
      {
      print "Error: No service state provided.\n";
      print_usage();
      exit 2;
      }
   }
else
   {
   if (!defined($state))
      {
      print "Error: No host state provided.\n";
      print_usage();
      exit 2;
      }
   }

if (defined($servicedesc))
   {
   if (defined($thruk))
      {
      $NagURL_extinfo = $NagURL . "thruk/cgi-bin/extinfo.cgi?type=2&host=";
      }
   else
      {
      $NagURL_extinfo = $NagURL . "nagios/cgi-bin/extinfo.cgi?type=2&host=";
      }
   }
else
   {
   if (defined($thruk))
      {
      $NagURL_extinfo = $NagURL . "thruk/cgi-bin/extinfo.cgi?type=1&host=";
      }
   else
      {
      $NagURL_extinfo = $NagURL . "nagios/cgi-bin/extinfo.cgi?type=1&host=";
      }
   }
     
if (defined($thruk))
   {
   $NagURL_status = $NagURL . "thruk/cgi-bin/status.cgi?host=";
   }
else
   {
   $NagURL_status = $NagURL . "nagios/cgi-bin/status.cgi?host=";
   }

$mail{smtp} = $smtphost;

if ((defined($servicedesc)) && ($servicedesc ne ""))
   {
   $mail{subject} = "Nagios: $notificationtype service $servicedesc on $hostname is $state";
   }
else
   {
   $mail{subject} = "Nagios: $notificationtype $hostname is $state";
   }
   

# If the mail server requires authentication, try this line:
# $mail{auth} = {user => "<username>", password => "<mailpw>", method => "LOGIN PLAIN", required => 1};

# check if the logo file exists

if (-e $logofile)
   {
   # In emails, images need to be base64 encoded, we encode the logo here
   $logo_img = b64encode_img($logofile);
 
   # extract the image format from the file extension
   $logo_type = ($logofile =~ m/([^.]+)$/)[0];
   $logofile = basename($logofile);
   }
else
   {
   # If the logo file cannot be found, we send a 1x1px empty logo image instead
   $logo_img = $empty_img;
   $logo_type = "gif";
   }

create_boundary();
create_message_text();
create_message_html();

$mail{'content-type'} = qq(multipart/alternative; boundary="$boundary1");

# Here we define the mail content to be send
my $mail_content = "This is a multi-part message in MIME format.\n";
 
# create the first boundary start marker for the main message (text)
$mail_content = $mail_content . '--' . "$boundary1\n";
$mail_content = $mail_content . "Content-Type: text/plain; charset=utf-8\n";
$mail_content = $mail_content . "Content-Transfer-Encoding: 8bit\n\n";
$mail_content = $mail_content . "$text_msg\n";
$mail_content = $mail_content . '--' . "$boundary1\n";

# create the second boundary start marker for the main message (html)
$mail_content = $mail_content . "Content-Type: multipart/related; boundary=\"$boundary2\"\n\n";
$mail_content = $mail_content . '--' . "$boundary2\n";
$mail_content = $mail_content . "Content-Type: text/html; charset=utf-8\n";
$mail_content = $mail_content . "Content-Transfer-Encoding: 8bit\n\n";
$mail_content = $mail_content . "$html_msg\n";

# create the third boundary marker for the logo image
$mail_content = $mail_content . '--' . "$boundary2\n";
$mail_content = $mail_content . "Content-Type: image/$logo_type; name=\"$logofile\"\n";
$mail_content = $mail_content . "Content-Transfer-Encoding: base64\n";
$mail_content = $mail_content . "Content-ID: <$logo_id>\n";
$mail_content = $mail_content . "Content-Disposition: inline; filename=\"$logofile\"\n\n";
$mail_content = $mail_content . "$logo_img\n";

# create the final end boundary marker
$mail_content = $mail_content . '--' . $boundary2 . "--\n\n";
$mail_content = $mail_content . '--' . $boundary1 . "--\n";

# put the completed message body into the mail
$mail{body} = $mail_content ;

sendmail(%mail) or die $Mail::Sendmail::error;
exit 0;

#--- Begin subroutines ------------------------------------------------------



#########################################################################
# unique content ID are needed for multipart messages with inline logos
#########################################################################

sub create_content_id
    {
    my $unique_string;
    my $content_id;

    $unique_string = rand(100);
    $unique_string = $unique_string . substr(md5_hex(time()),0,23);
    $unique_string =~ s/(.{5})/$1\./g;
    $content_id = qq(part.${unique_string}\@) . "MAIL";
    $unique_string = undef;
    return $content_id;
    }

# create_boundary creates the S/MIME multipart boundary strings

sub create_boundary
    {
    my $unique_string;
    
    $unique_string = substr(md5_hex(time()),0,24);
    $boundary1 = '======Part1=' . $unique_string ;
    $unique_string = undef;

    $unique_string = substr(md5_hex(time()),0,24);
    $boundary2 = '======Part2=' . $unique_string ;
    $unique_string = undef;

    }

sub unknown_arg
    {
    print_usage();
    exit 2;
    }


# Create a plaintext message -> $text_msg

sub create_message_text
    {
    $text_msg = "Nagios Monitoring System Notification\n" . "=====================================\n\n";

  
    $text_msg =$text_msg . "Notification Type: $notificationtype\n";
    $text_msg =$text_msg . "Host/Service Status: $state\n";
    $text_msg =$text_msg . "Hostname: $hostname\n";

    if (defined($hostalias))
       {
       $text_msg =$text_msg . "Hostalias: $hostalias\n";
       }
       
    $text_msg =$text_msg . "Host Address: $hostaddress\n";

    if ((defined($servicedesc)) && ($servicedesc ne ""))
       {
       $servicedesc =~  s/<br>/\n/isog;
       $servicedesc =~  s/<[^<>]*>//isog;
       $text_msg =$text_msg . "Service Name: $servicedesc\n";
       $text_msg =$text_msg . "Service Data: $serviceoutput\n\n";
       }

    # if author and comment data has been passed from Nagios
    # and these variables have content, then we add two more columns

    if (( defined($notificationauthor) && defined($notificationcmt)) && (($notificationauthor ne "") && ($notificationcmt ne "")))
       {
       $text_msg =$text_msg . "Author: $notificationauthor\n";
       $text_msg =$text_msg . "Comment: $notificationcmt\n\n";
       }

    $text_msg =$text_msg . "Event Time: $datetime\n\n";
    $text_msg =$text_msg . "-------------------------------------\n";
    }

# Create a HTML message -> $html_msg, per flags include URL's and IMG's

sub create_message_html
    {
    my $cellcolor;
    my $html_style;


    # Start HTML message definition
    $html_msg = "<html><head><title>Nagios Monitoring System Notification</title></head><body><p><font face=\"Arial\" size=\"2\">\n";
    $html_msg = $html_msg . "<table bgcolor=\"#e1e1e1\" border=\"0\" cellpadding=\"3\" cellspacing=\"0\" width=\"600px\"><tr>\n";
    
    $logo_id  = create_content_id();
    $html_msg =  $html_msg . "<td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
    $html_msg =  $html_msg . "<img style=\"width: 82px; height: 62px;\" src=\"cid:$logo_id\"></td>";
    $html_msg =  $html_msg . "<td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\"><strong>";
    $html_msg =  $html_msg . "<font font=\"\" color=\"#800000\" face=\"Arial\" size=\"5\">";
    $html_msg =  $html_msg . "Nagios Monitoring System Notification</font></strong></td></tr>\n";
  
    $cellcolor = $NOTIFICATIONCOLOR{$notificationtype};
    
    if ($state eq "WARNING")
       {
       $cellcolor = $NOTIFICATIONCOLOR{PROBLEM_WARN};
       }
       
    $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
    $html_msg = $html_msg . "<p><font color=\"#800000\" face=\"Arial\" size=\"2\">Notification Type:</font></p>";
    $html_msg = $html_msg . "</td>\n";
    $html_msg = $html_msg . "<td align=\"left\"  bgcolor=$cellcolor valign=\"top\" width=\"470px\">\n";
    $html_msg = $html_msg . "<p><strong><font face=\"Arial\" size=\"2\"> $notificationtype</font></strong></p>";
    $html_msg = $html_msg . "</td></tr>\n";

    $cellcolor = $NOTIFICATIONCOLOR{$state};
    $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
    $html_msg = $html_msg . "<p><font color=\"#800000\" face=\"Arial\" size=\"2\">Host/Service State:</font></p>";
    $html_msg = $html_msg . "</td>\n";
    $html_msg = $html_msg . "<td align=\"left\"  bgcolor=$cellcolor valign=\"top\" width=\"470px\">\n";
    $html_msg = $html_msg . "<p><strong><font face=\"Arial\" size=\"2\"> $state</font></strong></p>";
    $html_msg = $html_msg . "</td></tr>\n";

    $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
    $html_msg = $html_msg . "<font color=\"#800000\" face=\"Arial\" size=\"2\">Hostname:</font><br>";
    $html_msg = $html_msg . "</td>\n";

    $html_msg = $html_msg . "<td align=\"left\"  bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\">\n";

    # The Hostname URL http://<nagios-web>/cgi-bin/status.cgi?host=$HOSTNAME$&style=detail
    # this URL shows the host and all services underneath it
   
    $html_msg = $html_msg . "<font face=\"Arial\" size=\"2\">$hostname<br><br>(<a href=\"$NagURL_status" . urlencode($hostname) . "\">Click</a> to see host overview in Nagios)</font><br>";
    $html_msg = $html_msg . "</td></tr>\n";
    
    if ((defined($hostalias)) && ($hostalias ne ""))
       {
       $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
       $html_msg = $html_msg . "<font color=\"#800000\" face=\"Arial\" size=\"2\">Hostalias:</font><br>";
       $html_msg = $html_msg . "</td>\n";
       $html_msg = $html_msg . "<td align=\"left\"  bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\">\n";
       $html_msg = $html_msg . "<font face=\"Arial\" size=\"2\"> $hostalias</font><br>";
       $html_msg = $html_msg . "</td></tr>\n";
       } 

    $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
    $html_msg = $html_msg . "<font color=\"#800000\" face=\"Arial\" size=\"2\">Host Address:</font><br>";
    $html_msg = $html_msg . "</td>\n";
    $html_msg = $html_msg . "<td align=\"left\"  bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\">\n";
    $html_msg = $html_msg . "<font face=\"Arial\" size=\"2\"> $hostaddress</font><br>";
    $html_msg = $html_msg . "</td></tr>\n";

  
    # Print the service state, set the cell color based on the value CRITICAL, WARNING, OK, UNKNOWN
    

    if ((defined($servicedesc)) && ($servicedesc ne ""))
       {
       $serviceoutput =~ s/\n/<br>/g;
       $serviceoutput =~ s/\\n/<br>/g;
       
       $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
       $html_msg = $html_msg . "<font color=\"#800000\" face=\"Arial\" size=\"2\">Service Name:</font><br>";
       $html_msg = $html_msg . "</td>\n";
       $html_msg = $html_msg . "<td align=\"left\"  bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\">\n";
       $html_msg = $html_msg . "<font face=\"Arial\" size=\"2\"> $servicedesc</font><br>";
       $html_msg = $html_msg . "</td></tr>\n";
       
       $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
       $html_msg = $html_msg . "<font color=\"#800000\" face=\"Arial\" size=\"2\">Service Output:</font><br>";
       $html_msg = $html_msg . "</td>\n";
       $html_msg = $html_msg . "<td align=\"left\"  bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\">\n";
       $html_msg = $html_msg . "<font face=\"Arial\" size=\"2\">$serviceoutput<br><br>(<a href=\"$NagURL_extinfo" . urlencode($hostname) . "&service=" . urlencode($servicedesc) . "\">Click</a> to see detailed service info in Nagios)</font><br>\n";
       }
  
    $html_msg = $html_msg . "</td></tr>\n";

    # If the author and comment data has been passed from nagios
    # and these variables have content, then we add two more columns

    if ( ( defined($notificationauthor) && defined($notificationcmt) ) && ( ($notificationauthor ne "") && ($notificationcmt ne "") ) )
       {
       $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
       $html_msg = $html_msg . "<font color=\"#800000\" face=\"Arial\" size=\"2\">Author:</font><br>";
       $html_msg = $html_msg . "</td>\n";
       $html_msg = $html_msg . "<td align=\"left\"  bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\">\n";
       $html_msg = $html_msg . "<font face=\"Arial\" size=\"2\">$notificationauthor</font><br>";
       $html_msg = $html_msg . "</td></tr>\n";

       $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
       $html_msg = $html_msg . "<font color=\"#800000\" face=\"Arial\" size=\"2\">Comment:</font><br>";
       $html_msg = $html_msg . "</td>\n";
       $html_msg = $html_msg . "<td align=\"left\"  bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\">\n";
       $html_msg = $html_msg . "<font face=\"Arial\" size=\"2\">$notificationcmt</font><br>";
       $html_msg = $html_msg . "</td></tr>\n";
       }

    $html_msg = $html_msg . "<tr><td align=\"left\" bgcolor=\"#ffffff\" valign=\"top\" width=\"130px\">";
    $html_msg = $html_msg . "<font color=\"#800000\" face=\"Arial\" size=\"2\">Event Time:</font><br>";
    $html_msg = $html_msg . "</td>\n";
    $html_msg = $html_msg . "<td align=\"left\"  bgcolor=\"#ffffff\" valign=\"top\" width=\"470px\">\n";
    $html_msg = $html_msg . "<font face=\"Arial\" size=\"2\">$datetime</font><br>";
    $html_msg = $html_msg . "</td></tr>\n";
    $html_msg = $html_msg . "</table>\n";

    # End HTML message definition
    $html_msg = $html_msg . "</body></html>\n";
    }


# urlencode() URL encode a string

sub urlencode
    {
    my $urldata = $_[0];
    my $MetaChars = quotemeta( '-;,/?\|=+)(*&^%$#@!~`:');
    
    $urldata =~ s/([$MetaChars\"\'\x80-\xFF])/"%" . uc(sprintf("%2.2x",         ord($1)))/eg;
    $urldata =~ s/ /\+/g;
    return $urldata;
    }


# b64encode_image(filename) converts a existing binary source image file
# into a base64-image string.

sub b64encode_img
    {
    my($inputfile) = @_;
    my $b64encoded_img;
    
    open (IMG, $inputfile);
    binmode IMG; undef $/;
    $b64encoded_img = encode_base64(<IMG>);
    close IMG;
    return $b64encoded_img;
    }

sub print_version
    {
    print "\nnmon_send_mail.pl version : $ProgVersion\n\n";
    }

sub print_usage
    {
    print "\n";
    print "Usage: $0 [-V|--version]\n";
    print "or\n";
    print "Usage: $0 [-h|--help]\n";
    print "or\n";
    print "Usage: $0 ";
    print "[-c, --configuration=<path to config file>] \n";
    print "[-S|--smtphost <SMTP host>] \n";
    print " -N|--nagios <monitor.mydomain.net> \n";
    print " -r|--recipients <recipients> \n";
    print "    --notificationtype <notificationtype> \n";
    print "   [--datetime <datetime>] \n";
    print "   [--hostaddress <hostaddress>] \n";
    print "   [--hostname <hostname>] \n";
    print "   [--hostalias <hostalias>] \n";
    print "   [-t|--thruk] \n";
    print "   [-s|--ssl] \n";
    print "   [--notificationauthor <notificationauthor>] \n";
    print "   [--notificationcmt <notificationcmt>] \n";
    print "   [--servicedesc <servicedesc>] \n";
    print "   [--servicedispname <servicedisplayname>] \n";
    print "   [--serviceoutput <serviceoutput>] \n";
    print "   [--longserviceoutput <longserviceoutput] \n";
    print "   [--state <host or service state>]\n";
    }

sub help
    {
    print "\nMonitor system mail notification script, version ",$ProgVersion,"\n";
    print "GPL licence, (c)2012,2015 Frank Migge, (c)2017 Martin Fuerstenau\n";
    print_usage();
    print "\n";

    print "This script takes over email notifications by receiving the monitor system state\n";
    print "information, formatting the email and sending it out through an SMTP gateway.\n";
    print "\n";
    print "-V, --version                                 Prints version number.\n";
    print "-h, --help                                    Print this help message.\n";
    print "\n";
    print "-c, --configuration=<path to config file>     Path to configuration file\n";
    print "                                              Default will be path of the script\n";
    print "                                              and script name without .pl and .cfg\n";
    print "                                              instead.\n";
    print "\n";
    print "                                              Example:\n";
    print "                                              foo.pl -> foo.cfg\n";
    print "\n";
    print "-S, -smtphost=<HOST>                          Name or IP address of SMTP gateway.\n";
    print "-N, --nagios=<Nagios Host>                    Name of the monitor host (i.e. monitor.mydomain.net)\n";
    print "-r, --recipients <addr1,addr2,...>            Comma-separated list of all contact \n";
    print "                                              mail addresses that are being notified\n";
    print "                                              about the host or service.\n";
    print "\n";
    print "    --notificationtype=notificationtype       Nagios notificationtype.A string identifying\n";
    print "                                              the type of notification that is being sent:\n";
    print "                                              - PROBLEM\n";
    print "                                              - RECOVERY\n";
    print "                                              - ACKNOWLEDGEMENT\n";
    print "                                              - FLAPPINGSTART\n";
    print "                                              - FLAPPINGSTOP\n";
    print "                                              - FLAPPINGDISABLED\n";
    print "                                              - DOWNTIMESTART\n";
    print "                                              - DOWNTIMEEND\n";
    print "                                              - DOWNTIMECANCELLED\n";
    print "\n";
    print "    --datetime=<datetime>                     Nagios datetime (long or short as handed over).\n";
    print "    --hostaddress=<hostaddress>               Address of the host. This value is taken from the\n";
    print "                                              address directive in the host definition.\n";
    print "    --hostname=<hostname>                     Short name for the host (i.e. \"biglinuxbox\").\n";
    print "                                              This value is taken from the host_name directive in\n";
    print "                                              the host definition.\n";
    print "    --hostalias=<hostalias>                   Nagios hostalias.Long name/description for the host.\n";
    print "                                              This value is taken from the alias directive in\n";
    print "                                              the host definition.\n";
    print "\n";
    print "-t | --thruk                                  If set use Thruk for links to Nagios instead of\n";
    print "                                              classical view.\n";
    print "-s | --ssl                                    Use https instead of http.\n";
    print "\n";
    print "    --notificationauthor=notificationauthor    A string containing the name of the user who authored\n";
    print "                                             the notification. If the \$NOTIFICATIONTYPE\$ macro is\n";
    print "                                             set to \"DOWNTIMESTART\" or \"DOWNTIMEEND\", this will\n";
    print "                                             be the name of the user who scheduled downtime for the\n";
    print "                                             host or service. If the \$NOTIFICATIONTYPE\$ macro is\n";
    print "                                             \"ACKNOWLEDGEMENT\", this will be the name of the user\n";
    print "                                             who acknowledged the host or service problem. If the\n";
    print "                                             \$NOTIFICATIONTYPE\$ macro is \"CUSTOM\", this will be\n";
    print "                                             name of the user who initated the custom host or service\n";
    print "                                             notification.\n";
    print "    --notificationcmt=notificationcmt        A string containing the comment that was entered by the\n";
    print "                                             notification author. If the \$NOTIFICATIONTYPE\$ macro\n";
    print "                                             is set to \"DOWNTIMESTART\" or \"DOWNTIMEEND\", this will\n";
    print "                                             be the comment entered by the user who scheduled downtime\n";
    print "                                             for the host or service. If the \$NOTIFICATIONTYPE\$ macro\n";
    print "                                             is \"ACKNOWLEDGEMENT\", this will be the comment entered\n";
    print "                                             by the user who acknowledged the host or service problem.\n";
    print "                                             If the \$NOTIFICATIONTYPE\$ macro is \"CUSTOM\", this will\n";
    print "                                             be comment entered by the user who initated the custom host\n";
    print "                                             or service notification.\n";
    print "    --servicedesc=servicedesc                Nagios service description.The long name/description of\n";
    print "                                             the service (i.e. \"Main Website\"). This value is taken\n";
    print "                                             from the service_description directive of the service\n";
    print "                                             definition.\n";
    print "    --servicedispname=servicedisplayname     An alternate display name for the service. This value is\n";
    print "                                             taken from the display_name directive in the service definition.\n";
    print "    --serviceoutput=serviceoutput            The first line of text output from the last service check\n";
    print "                                             (i.e. \"Ping OK\").\n";
    print "    --longserviceoutput=longserviceoutput    The full text output (aside from the first line) from the\n";
    print "                                             last service check.\n";
    print "    --state=state                            Nagios service state or host state.\n";
    }
