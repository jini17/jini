Program name: mon_send_mail.pl

Author: Martin Fuerstenau
        martin.fuerstenau_at_oce.com

Date:   10 May 2012
 
Purpose:
========

- Submitting alert HTML formatted emails emails from a *agios based monitor system to the contact (icinga,op5,opsview...)

Features of the program:
========================

- Simple replacement for standard construct (printf.....| mail)
- Userdefined logo in mail
- Colors freely definable
- Clickable links to monitor.

License
=======
License: GPL
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

History and Changes:
====================
 
The plugin is a fork by Martin Fuerstenau (martin.fuerstenau@oce.com) of the original one 
nagios_send_service_mail.pl written by Frank Migge (support at frank4dd dot com)
and Robert Brecht published May 20, 2015, (c)2012 Frank Migge. Opposit to Frank's plugin
the intention was not to send all the informations from the monitor (including performance
graphs see http://nagios.fm4dd.com/plugins/ for Frank's scripts) by mail. But it was
unnecessary to reinvent the wheel. So a lot of codes was (re)used for this script..

- 12 Mar 2017 M.Fuerstenau
  - Started with actual version 1.8
  - Removed all "unnecessary" stuff
    - Removed sending graphs for pnp4nagios
    - Removed sending graphs for nagiosgraph
    - Removed support for hostgroups
    - Removed support for servicegroups
    - Removed support for cc and bcc (doesn't make sense).
    - Removed debug and test function. Not necessary.
    - Removed supporting languages. English hard coded
    - Removed using supporting languages. English hard coded
    - Removed create_address() using supporting languages. English hard coded

  - Changed
    - Changed from global variables to "my", because using this 
      the purpose of the variables can be documented better.
    - Reformatted code for better readability
    - Simplified variable names.
    - Changed from sending either HTML mail or text mail to a multipart mail
      containing both
    - Changedusing environment variables for handing over nagios macros ($SERVICESDESC$) etc..
      THIS IS IMPORTANT BECAUSE USING THE VARIABLES CAN CAUSE PERFORMANCE ISSUES
      IN NAGIOS. Therefore this should be disabled in Nagios. With every run of a plugin
      the whole environment is exported to the plugin. Nightmare. All parameters will now
      be submitted using command line options.

  - Added
    - Option -t. This tells for the link to the monitor systeme whether Thruk
      will be used or the classical interface.
    - Added filtering out HTML code from service output for text mails
    - Added replaceing new line by <br> for  HTML mails

- 14 Nov 2017 M.Fuerstenau
  - Added
    - Moved all definitions users can adopt to seperate configuration file
  

Prerequisites:
==============

- Perl and some of modules:
  Getopt::Long
  Mail::Sendmail
  Digest::MD5 qw(md5_hex)
  MIME::Base64
  File::Temp
  File::Basename
 
- System must be able to send mails


Installation & Configuration:
=============================

Place mon_send_mail.pl and mon_send_mail.cfg in a directory of your choice.

It is generally a bad idea to mix plugins deliverd by your monitoring systeme and third party plugins. 
It may be new for some but you can have more than one directory for plugins, configuration files etc..

If the configuration file
is not located in the same directory as the program and doesn't have the same name as the program (.cfg
instead of .pl) yuo must tell the program where to found via commandline option (see below).

monitoring.png can be placed and/or renamed wherever you want. You can use your own logo with your own 
name. The logo path will be configured in the .cfg file. 


Configuration file
------------------

The configuration file is a piece of perl code. The main goal was to have all definitions a user must edit
in a seperate file.

Please configure
- Path to logo file
- mail sender
  Remark: This should normally being a valid user able to get mails and not nagios@localhost
  Email adminstrators are mostly not amused when getting absence mails etc. which can be 
  deployed to the sender.
  
The hash %NOTIFICATIONCOLOR contains the used colours. Feel free to change them.


Configuration/modifications in the code
---------------------------------------

Normally there is no nned to do this execpt one thing. I developed the script for Nagios 3.x using Thruk.
So while there is an option (-t) to select the right HTML link generated into the mail for getting the
right Nagios window in browser, this should be adopted for Nagios 4.x, Naemon, Icinga, Shinken... .

The code is located around line 279:

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

This should be easy to adopt by copying parts from the URL from your browser.

PLEASE SEND ME YOUR MODIFICATION FOR OTHER MONITORS SO I CAN MODIFY THE PROGRAM!!!


Sample monitor command definition
---------------------------------

define command{
       command_name    notify-by-email
       command_line    /usr/lib/nagios/send_mail/mon_send_mail.pl -N monitor-ac.oce.net -s -t --hostname=$HOSTNAME$ --hostalias=$HOSTALIAS$ --hostaddress=$HOSTADDRESS$ -r $CONTACTEMAIL$ --notificationtype=$NOTIFICATIONTYPE$ --notificationauthor="$NOTIFICATIONAUTHOR$" --notificationcmt="$NOTIFICATIONCOMMENT$" --servicedesc="$SERVICEDESC$" --serviceoutput="$SERVICEOUTPUT$\n$LONGSERVICEOUTPUT$" --state=$SERVICESTATE$ --datetime="$SHORTDATETIME$"
       }


Command reference
=================

Monitor system mail notification script, version 2.0.0
GPL licence, (c)2012,2015 Frank Migge, (c)2017 Martin Fuerstenau

Usage: ./mon_send_mail2.pl [-V|--version]
or
Usage: ./mon_send_mail2.pl [-h|--help]
or
Usage: ./mon_send_mail2.pl [-c, --configuration=<path to config file>] 
[-S|--smtphost <SMTP host>] 
 -N|--nagios <monitor.mydomain.net> 
 -r|--recipients <recipients> 
    --notificationtype <notificationtype> 
   [--datetime <datetime>] 
   [--hostaddress <hostaddress>] 
   [--hostname <hostname>] 
   [--hostalias <hostalias>] 
   [-t|--thruk] 
   [-s|--ssl] 
   [--notificationauthor <notificationauthor>] 
   [--notificationcmt <notificationcmt>] 
   [--servicedesc <servicedesc>] 
   [--servicedispname <servicedisplayname>] 
   [--serviceoutput <serviceoutput>] 
   [--longserviceoutput <longserviceoutput] 
   [--state <host or service state>]

This script takes over email notifications by receiving the monitor system state
information, formatting the email and sending it out through an SMTP gateway.

-V, --version                                 Prints version number.
-h, --help                                    Print this help message.

-c, --configuration=<path to config file>     Path to configuration file
                                              Default will be path of the script
                                              and script name without .pl and .cfg
                                              instead.

                                              Example:
                                              foo.pl -> foo.cfg

-S, --smtphost=<HOST>                         Name or IP address of SMTP gateway.
-N, --nagios=<Nagios Host>                    Name of the monitor host (i.e. monitor.mydomain.net)
-r, --recipients <addr1,addr2,...>            Comma-separated list of all contact 
                                              mail addresses that are being notified
                                              about the host or service.

    --notificationtype=notificationtype       Nagios notificationtype.A string identifying
                                              the type of notification that is being sent:
                                              - PROBLEM
                                              - RECOVERY
                                              - ACKNOWLEDGEMENT
                                              - FLAPPINGSTART
                                              - FLAPPINGSTOP
                                              - FLAPPINGDISABLED
                                              - DOWNTIMESTART
                                              - DOWNTIMEEND
                                              - DOWNTIMECANCELLED

    --datetime=<datetime>                     Nagios datetime (long or short as handed over).
    --hostaddress=<hostaddress>               Address of the host. This value is taken from the
                                              address directive in the host definition.
    --hostname=<hostname>                     Short name for the host (i.e. "biglinuxbox").
                                              This value is taken from the host_name directive in
                                              the host definition.
    --hostalias=<hostalias>                   Nagios hostalias.Long name/description for the host.
                                              This value is taken from the alias directive in
                                              the host definition.

-t | --thruk                                  If set use Thruk for links to Nagios instead of
                                              classical view.
-s | --ssl                                    Use https instead of http.

    --notificationauthor=notificationauthor    A string containing the name of the user who authored
                                             the notification. If the $NOTIFICATIONTYPE$ macro is
                                             set to "DOWNTIMESTART" or "DOWNTIMEEND", this will
                                             be the name of the user who scheduled downtime for the
                                             host or service. If the $NOTIFICATIONTYPE$ macro is
                                             "ACKNOWLEDGEMENT", this will be the name of the user
                                             who acknowledged the host or service problem. If the
                                             $NOTIFICATIONTYPE$ macro is "CUSTOM", this will be
                                             name of the user who initated the custom host or service
                                             notification.
    --notificationcmt=notificationcmt        A string containing the comment that was entered by the
                                             notification author. If the $NOTIFICATIONTYPE$ macro
                                             is set to "DOWNTIMESTART" or "DOWNTIMEEND", this will
                                             be the comment entered by the user who scheduled downtime
                                             for the host or service. If the $NOTIFICATIONTYPE$ macro
                                             is "ACKNOWLEDGEMENT", this will be the comment entered
                                             by the user who acknowledged the host or service problem.
                                             If the $NOTIFICATIONTYPE$ macro is "CUSTOM", this will
                                             be comment entered by the user who initated the custom host
                                             or service notification.
    --servicedesc=servicedesc                Nagios service description.The long name/description of
                                             the service (i.e. "Main Website"). This value is taken
                                             from the service_description directive of the service
                                             definition.
    --servicedispname=servicedisplayname     An alternate display name for the service. This value is
                                             taken from the display_name directive in the service definition.
    --serviceoutput=serviceoutput            The first line of text output from the last service check
                                             (i.e. "Ping OK").
    --longserviceoutput=longserviceoutput    The full text output (aside from the first line) from the
                                             last service check.
    --state=state                            Nagios service state or host state.
