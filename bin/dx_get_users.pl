# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright (c) 2015,2016 by Delphix. All rights reserved.
# 
# Program Name : dx_get_users.pl
# Description  : Get database and host information
# Author       : Marcin Przepiorowski
# Created      : 22 Apr 2015 (v2.0.0)
#
#


use strict;
use warnings;
use JSON;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev); #avoids conflicts with ex host and help
use File::Basename;
use Pod::Usage;
use FindBin;
use Data::Dumper;

my $abspath = $FindBin::Bin;

use lib '../lib';
use Engine;
use User_obj;
use Formater;
use Toolkit_helpers;
use Users;


my $version = $Toolkit_helpers::version;

GetOptions(
  'help|?' => \(my $help), 
  'd|engine=s' => \(my $dx_host), 
  'format=s' => \(my $format),
  'save=s' => \(my $save),
  'export=s' => \(my $export),
  'username=s' => \(my $username),
  'profile:s' => \(my $profile),
  'all' => (\my $all),
  'dever=s' => \(my $dever),
  'version' => \(my $print_version),
  'debug:n' => \(my $debug),
  'nohead' => \(my $nohead)
) or pod2usage(-verbose => 1,  -input=>\*DATA);

pod2usage(-verbose => 2,  -input=>\*DATA) && exit if $help;
die  "$version\n" if $print_version;   

Toolkit_helpers::check_format_opions($format);

my $engine_obj = new Engine ($dever, $debug);
my $path = $FindBin::Bin;
my $config_file = $path . '/dxtools.conf';

$engine_obj->load_config($config_file);

if (defined($all) && defined($dx_host)) {
  print "Option all (-all) and engine (-d|engine) are mutually exclusive \n";
  pod2usage(-verbose => 1,  -input=>\*DATA);
  exit (1);
}

my $output = new Formater();
my $output_profile = new Formater();


if (defined($export)) {
  $output->addHeader(
    {'Command',    1},
    {'Username',    20},
    {'First Name',  20},
    {'Last Name',   20},
    {'Email',       30},
    {'work phone',   12},
    {'home phone',   12},
    {'mobile phone', 12},
    {'Authtype',    8},
    {'principal', 30},
    {'password', 8},
    {'admin_priv', 8},
    {'js_user', 8}
  );
  $save = $export;
  $format = 'csv';
} else {
  $output->addHeader(
    {'Username',    20},
    {'First Name',  20},
    {'Last Name',   20},
    {'Email',       30},
    {'work phone',   12},
    {'home phone',   12},
    {'mobile phone', 12},
    {'Authtype',    8},
    {'principal', 30},
    {'password', 8},
    {'admin_priv', 8},
    {'js_user', 8}
  );
}


$output_profile->addHeader(
  {'Username',    20},
  {'Type',        20},
  {'Name',        20},
  {'Role',        30}
);

# this array will have all engines to go through (if -d is specified it will be only one engine)
my $engine_list = Toolkit_helpers::get_engine_list($all, $dx_host, $engine_obj); 

my $FD;
my $FDPROF;

if (defined($save)) {
  open($FD,'>',$save) or die("Can't open file $save $!" );
}

if (defined($profile) && ($profile ne '')) {
  open($FDPROF,'>',$profile) or die("Can't open file $profile $!" );
}

for my $engine ( sort (@{$engine_list}) ) {
  # main loop for all work
  if ($engine_obj->dlpx_connect($engine)) {
    print "Can't connect to Dephix Engine $dx_host\n\n";
    next;
  };



  # load objects for current engine
  my $users_obj = new Users ($engine_obj, undef, $debug);
  my @user_list;

  if (defined($username)) {
    push (@user_list, $users_obj->getUserByName($username)->getReference());
  } else {
    @user_list = $users_obj->getUsers();
  }

  for my $userref ( @user_list ) {
    my $user = $users_obj->getUser($userref);
    my ($first_name, $last_name) = $user->getNames();
    my ($email_address, $work_phone, $home_phone, $cell_phone) = $user->getContact();
    my ($type, $principal, $password) = $user->getAuthentication();
    if ($type eq 'LDAP') {

    }

    if (defined($export)) {
      $output->addLine(
        'C',
        $user->getName(),
        $first_name,
        $last_name,
        $email_address, 
        $work_phone, 
        $home_phone, 
        $cell_phone,
        $type,
        $principal,
        $password,
        $user->isAdmin() ? 'Y' : 'N',
        $user->isJS() ? 'Y' : 'N'
      );
    } else {
      $output->addLine(
        $user->getName(),
        $first_name,
        $last_name,
        $email_address, 
        $work_phone, 
        $home_phone, 
        $cell_phone,
        $type,
        $principal,
        $password,
        $user->isAdmin() ? 'Y' : 'N',
        $user->isJS() ? 'Y' : 'N'
      );
    }
    if (defined($profile)) {
      my $profile_data = $user->getProfile();
            
      for my $item (sort (keys %{$profile_data->{'group'} } ) ) {
          $output_profile->addLine(
            $user->getName(),
            'group',
            $item,
            $profile_data->{'group'}->{$item}
          );
      }
      for my $item (sort ( keys %{$profile_data->{'databases'} } ) ) {
          $output_profile->addLine(
            $user->getName(),
            'databases',
            $item,
            $profile_data->{'databases'}->{$item}
          );
      }
    }

  }


  Toolkit_helpers::print_output($output, $format, $nohead, $FD);


  if (defined($profile)) {
    Toolkit_helpers::print_output($output_profile, $format, $nohead, $FDPROF);
  }




}

if (defined($save)) {
  close($FD);
}

if (defined($profile)) {
  close($FDPROF);
}




__DATA__


=head1 SYNOPSIS

 dx_get_users    [ -engine|d <delphix identifier> | -all ] 
                 [ -format output_format ] 
                 [ -save file_name] 
                 [ -username <username> ] 
                 [ -profile filename] 
                 [ -export filename ] 
                 [ -help|? ] 
                 [ -debug ]

=head1 DESCRIPTION

Get users information from Delphix Engine.

=head1 ARGUMENTS

=head2 Delphix Engine selection - if not specified a default host(s) from dxtools.conf will be used.

=over 4

=item B<-engine|d>
Specify Delphix Engine name from dxtools.conf file

=item B<-all>
Display databases on all Delphix appliance

=back

=head2 Options

=over 4

=item B<-format csv|json >
Define output format - csv or json
Pretty print if not specified

=item B<-save file_name>
Save data into file instead of screen

=item B<-username username>
Specify a username to display user profile for

=item B<-export filename>
Export users into file compatible with dx_ctl_users script

=item B<-profile filename>
Export users profile into file compatible with dx_ctl_users script


=back

=head1 OPTIONS

=over 2

=item B<-help>          
Print this screen

=item B<-debug>
Turn on debugging

=item B<-nohead>
Turn off csv and pretty print headers

=back

=head1 EXAMPLES

Display all users

 dx_get_users -d Landshark5

 Username             First Name           Last Name            Email                          work phone   home phone   mobile phone Authtype principal                      password admin_pr js_user
 -------------------- -------------------- -------------------- ------------------------------ ------------ ------------ ------------ -------- ------------------------------ -------- -------- --------
 sysadmin                                                       test@delphix.com                                                      NATIVE                                  password N        N
 delphix_admin                                                  test@delphix.com                                                      NATIVE                                  password Y        N
 dev_admin            Dev                  Eloper               dev_admin@delphix.com                       555-555-1212              NATIVE                                  password N        N
 qa_admin             QA                   Dude                 qa_admin@delphix.com                        555-555-1212              NATIVE                                  password N        N
 dev                  Dev                  Eloper               dev@delphix.com                             555-555-1212              NATIVE                                  password N        Y
 qa                   QA                   Dude                 qa@delphix.com                              555-555-1212              NATIVE                                  password N        Y



Export all users into files which can be used by dx_ctl_users

 dx_get_users -d SourceEngine -export /tmp/source/users.csv -profile /tmp/source/profile.csv
 
 


=cut



