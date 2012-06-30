# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT;
use warnings;
use strict;

our $VERSION = '4.0.6';



$BasePath = '/opt/rt3';
$EtcPath = '/opt/rt3/etc';
$BinPath = '/opt/rt3/bin';
$SbinPath = '/opt/rt3/sbin';
$VarPath = '/opt/rt3/var';
$LexiconPath = '/opt/rt3/share/po';
$PluginPath = '/opt/rt3/plugins';
$LocalPath = '/opt/rt3/local';
$LocalEtcPath = '/opt/rt3/local/etc';
$LocalLibPath        =    '/opt/rt3/local/lib';
$LocalLexiconPath = '/opt/rt3/local/po';
$LocalPluginPath = '/opt/rt3/local/plugins';
# $MasonComponentRoot is where your rt instance keeps its mason html files
$MasonComponentRoot = '/var/www/freeside/rt';
# $MasonLocalComponentRoot is where your rt instance keeps its site-local
# mason html files.
$MasonLocalComponentRoot = '/opt/rt3/local/html';
# $MasonDataDir Where mason keeps its datafiles
$MasonDataDir = '/usr/local/etc/freeside/masondata';
# RT needs to put session data (for preserving state between connections
# via the web interface)
$MasonSessionDir = '/opt/rt3/var/session_data';


1;
