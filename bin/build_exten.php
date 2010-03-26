#!/usr/bin/php -q
<?php /* $Id: build_exten.php,v 1.1 2010-03-26 02:19:16 ivan Exp $ */
//Copyright (C) 2008 Astrogen LLC
//
//This program is free software; you can redistribute it and/or
//modify it under the terms of the GNU General Public License
//as published by the Free Software Foundation; either version 2
//of the License, or (at your option) any later version.
//
//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.

function out($text) {
	echo $text."\n";
}

function outn($text) {
	echo $text;
}

function error($text) {
	echo "[ERROR] ".$text."\n";
}

function warning($text) {
	echo "[WARNING] ".$text."\n";
}

function fatal($text) {
	echo "[FATAL] ".$text."\n";
	exit(1);
}

function debug($text) {
	global $param_debug;
	
	if ($param_debug) echo "[DEBUG] ".$text."\n";
}

if (! @ include("Console/Getopt.php")) {
	fatal("PEAR must be installed (requires Console/Getopt.php). Include path: ".ini_get("include_path"));
	exit(12);
}

ini_set('error_reporting', E_ALL & ~E_NOTICE);

function showHelp() {
	global $argv;
	out("USAGE:");
	out("  ".$argv[0]." --create|delete --exten <extension> [optional parameters]");
	out("");

	out("OPERATIONS (exactly one must be specified):");
	out("  --create, -c");
	out("      Create a new extension");
	out("  --modify, -m");
	out("      Modify an existing extension, the extension must exist and all values execept");
	out("      those specified will remain the same");
	out("  --delete, -d");
	out("      Delete an extension");

	out("PARAMETERS:");
	out("  --exten extension_number");
	out("      Extension number to create or delete. Must be specified.");

	out("OPTIONAL PARAMETERS:");
	out("  --name name");
	out("      Display Name, defaults to specified extension number.");
	out("  --outboundcid cid_number");
	out("      Outbound CID Number, defaults to specified extension number.");
	out("  --directdid did_number");
	out("      Direct DID Number, defaults to extension number.");
	out("  --vm-password password");
	out("      Voicemail Password, defaults to specified extension number.");
	out("  --sip-secret secret");
	out("      SIP Secret, defaults to md5 hash of specified extension number.");
	out("  --debug");
	out("      Display debug messages.");
	out("  --no-warnings");
	out("      Do Not display warning messages.");

	out("  --help, -h, -?           Show this help");
}

// **** Parse out command-line options
$shortopts = "cmdh?";
$longopts = array(
	"help",
	"debug",
	"no-warnings",
	"create",
	"modify",
	"delete",
	"exten=",
	"outboundcid=",
	"directdid=",
	"name=",
	"sip-secret=",
	"vm-password=",
);

$args = Console_Getopt::getopt(Console_Getopt::readPHPArgv(), $shortopts, $longopts);
if (is_object($args)) {
	// assume it's PEAR_ERROR
	fatal($args->message);
	exit(255);
}

$no_params = true;

$param_debug = false;
$param_warnings = true;
$param_create = false;
$param_modify = false;
$param_delete = false;
$param_exten = false;
$param_name = false;
$param_outboundcid = false;
$param_directdid = false;
$param_sip_secret = false;
$param_vm_password = false;

foreach ($args[0] as $arg) {
	$no_params = false;
	switch ($arg[0]) {

		case "--help": 
		case "h": 
		case "?":
			showHelp();
			exit(10);
		break;

		case "--debug":
			$param_debug = true;
			debug("debug mode is enabled");
		break;

		case "--no-warnings":
			$param_warnings = false;
		break;

		case "--create":
		case "c": 
			$param_create = true;
		break;

		case "--modify":
		case "m": 
			$param_modify = true;
		break;

		case "--delete":
		case "d": 
			$param_delete = true;
		break;

		case "--exten":
			$param_exten = true;
			$new_exten = $arg[1];
		break;

		case "--outboundcid":
			$param_outboundcid = true;
			$new_outboundcid = $arg[1];
		break;

		case "--directdid":
			$param_directdid = true;
			$new_directdid = $arg[1];
		break;

		case "--name":
			$param_name = true;
			$new_name = $arg[1];
		break;

		case "--sip-secret":
			$param_sip_secret = true;
			$new_sip_secret = $arg[1];
		break;

		case "--vm-password":
			$param_vm_password = true;
			$new_vm_password = $arg[1];
		break;

		default:
			error("unhandled argument supplied: ".$arg[0].", aborting");
			exit (1);
	}
}

if ($no_params) {
	showHelp();
	exit(10);
}
if ($param_create && $param_modify) {
	error("Incompatible combination of options, create and modify");
	exit (1);
}
if (!(($param_create || $param_modify) XOR $param_delete)) {
	error("Invalid Parameter combination, you must include create or delete and can not do both in one call");
	exit (1);
}
if (!$param_exten) {
	error("You must provide an extension number to create or delete an extension");
	exit (1);
}

if ($param_warnings && $param_create) {
	if (!$param_outboundcid) {
		$new_outboundcid = $new_exten;
		warning("WARNING: No outboundcid specified for extenion, using $new_outboundcid as outboundcid");
	}
	if (!$param_directdid) {
		$new_directdid = $new_exten;
		warning("WARNING: No outboundcid specified for extenion, using $new_outboundcid as outboundcid");
	}
	if (!$param_name) {
		$new_name = $new_exten;
		warning("WARNING: No name specified for extenion, using $new_name as name");
	}
	if (!$param_sip_secret) {
		$new_sip_secret = md5($new_exten);
		warning("WARNING: No sip-secret specified for extenion, using $new_sip_secret as secret");
	}
	if (!$param_vm_password) {
		$new_vm_password = $new_exten;
		warning("WARNING: No vm-password specified for extenion, using $new_vm_password as password");
	}
}

// Now setup actions and exten how leveraged code expected it
//
$exten = $new_exten;
if ($param_create) {
	$actions = "addext/addvm";
} else if ($param_modify) {
	$actions =  "modext";
} else if ($param_delete) {
	$actions = "remext";
}

/* I don't think I need these but ???
*/
$type = 'setup';
$display = '';
$extdisplay = null;

// determine module type to show, default to 'setup'
$type_names = array(
	'tool'=>'Tools',
	'setup'=>'Setup',
	'cdrcost'=>'Call Cost',
);

define("AMP_CONF", "/etc/amportal.conf");
$amportalconf = AMP_CONF;

// bootstrap retrieve_conf by getting the AMPWEBROOT since that is currently where the necessary
// functions.inc.php resides, and then use that parser to properly parse the file and get all
// the defaults as needed.
//
function parse_amportal_conf_bootstrap($filename) {
	$file = file($filename);
	foreach ($file as $line) {
		if (preg_match("/^\s*([\w]+)\s*=\s*\"?([\w\/\:\.\*\%-]*)\"?\s*([;#].*)?/",$line,$matches)) {
			$conf[ $matches[1] ] = $matches[2];
		}
	}
	if ( !isset($conf["AMPWEBROOT"]) || ($conf["AMPWEBROOT"] == "")) {
		$conf["AMPWEBROOT"] = "/var/www/html";
	} else {
		$conf["AMPWEBROOT"] = rtrim($conf["AMPWEBROOT"],'/');
	}

	return $conf;
}

$amp_conf = parse_amportal_conf_bootstrap($amportalconf);
if (count($amp_conf) == 0) {
	exit (1);
}


// Emulate gettext extension functions if gettext is not available
if (!function_exists('_')) {
	function _($str) {
		return $str;
	}
}
if (!function_exists('gettext')) {
	function gettext($message) {
		return $message;
	}
}
if (!function_exists('dgettext')) {
	function dgettext($domain, $message) {
		return $message;
	}
}

// setup locale
function set_language() {
	if (extension_loaded('gettext')) {
		if (isset($_COOKIE['lang'])) {
			setlocale(LC_ALL,  $_COOKIE['lang']);
			putenv("LANGUAGE=".$_COOKIE['lang']);
		} else {
			setlocale(LC_ALL,  'en_US');
		}
		bindtextdomain('amp','./i18n');
		bind_textdomain_codeset('amp', 'utf8');
		textdomain('amp');
	}
}
set_language();

// systems running on sqlite3 (or pgsql) this function is not available
// instead of changing the whole code, lets hack our own version of this function.
// according to the documentation found here: http://il2.php.net/mysql_real_escape_string
// this shold be enough.
// Fixes ticket: http://freepbx.org/trac/ticket/1963
if (!function_exists('mysql_real_escape_string')) {
	function mysql_real_escape_string($str) {
		$str = str_replace( "\x00", "\\" . "\x00", $str );
		$str = str_replace( "\x1a", "\\" . "\x1a", $str );
		$str = str_replace( "\n" , "\\". "\n"    , $str );
		$str = str_replace( "\r" , "\\". "\r"    , $str );
		$str = str_replace( "\\" , "\\". "\\"    , $str );
		$str = str_replace( "'" , "''"           , $str );
		$str = str_replace( '"' , '""'           , $str );
		return $str;
	}
}

// include base functions

require_once($amp_conf['AMPWEBROOT']."/admin/functions.inc.php");
require_once($amp_conf['AMPWEBROOT']."/admin/common/php-asmanager.php");
$amp_conf = parse_amportal_conf($amportalconf);
if (count($amp_conf) == 0) {
	exit (1);
}
$asterisk_conf_file = $amp_conf["ASTETCDIR"]."/asterisk.conf";
$asterisk_conf = parse_asterisk_conf($asterisk_conf_file);

ini_set('include_path',ini_get('include_path').':'.$amp_conf['AMPWEBROOT'].'/admin/:');

$astman		= new AGI_AsteriskManager();

// attempt to connect to asterisk manager proxy
if (!isset($amp_conf["ASTMANAGERPROXYPORT"]) || !$res = $astman->connect("127.0.0.1:".$amp_conf["ASTMANAGERPROXYPORT"], $amp_conf["AMPMGRUSER"] , $amp_conf["AMPMGRPASS"])) {
	// attempt to connect directly to asterisk, if no proxy or if proxy failed
	if (!$res = $astman->connect("127.0.0.1:".$amp_conf["ASTMANAGERPORT"], $amp_conf["AMPMGRUSER"] , $amp_conf["AMPMGRPASS"])) {
		// couldn't connect at all
		unset( $astman );
	}
}
// connect to database
require_once($amp_conf['AMPWEBROOT']."/admin/common/db_connect.php");

$nt = notifications::create($db);

$framework_asterisk_running =  checkAstMan();

// get all enabled modules
// active_modules array used below and in drawselects function and genConf function
$active_modules = module_getinfo(false, MODULE_STATUS_ENABLED);

$fpbx_menu = array();

// pointer to current item in $fpbx_menu, if applicable
$cur_menuitem = null;

// add module sections to $fpbx_menu
$types = array();
if(is_array($active_modules)){
	foreach($active_modules as $key => $module) {
		//include module functions
		if (is_file($amp_conf['AMPWEBROOT']."/admin/modules/{$key}/functions.inc.php")) {
			require_once($amp_conf['AMPWEBROOT']."/admin/modules/{$key}/functions.inc.php");
		}
		
		// create an array of module sections to display
		// stored as [items][$type][$category][$name] = $displayvalue
		if (isset($module['items']) && is_array($module['items'])) {
			// loop through the types
			foreach($module['items'] as $itemKey => $item) {

				if (!$framework_asterisk_running && 
					  ((isset($item['needsenginedb']) && strtolower($item['needsenginedb'] == 'yes')) || 
					  (isset($item['needsenginerunning']) && strtolower($item['needsenginerunning'] == 'yes')))
				   )
				{
					$item['disabled'] = true;
				} else {
					$item['disabled'] = false;
				}

				if (!in_array($item['type'], $types)) {
					$types[] = $item['type'];
				}
				
				if (!isset($item['display'])) {
					$item['display'] = $itemKey;
				}
				
				// reference to the actual module
				$item['module'] =& $active_modules[$key];
				
				// item is an assoc array, with at least array(module=> name=>, category=>, type=>, display=>)
				$fpbx_menu[$itemKey] = $item;
				
				// allow a module to replace our main index page
				if (($item['display'] == 'index') && ($display == '')) {
					$display = 'index';
				}
				
				// check current item
				if ($display == $item['display']) {
					// found current menuitem, make a reference to it 
					$cur_menuitem =& $fpbx_menu[$itemKey];
				}
			}
		}
	}
}
sort($types);

// new gui hooks
if(is_array($active_modules)){
	foreach($active_modules as $key => $module) {
		if (isset($module['items']) && is_array($module['items'])) {
			foreach($module['items'] as $itemKey => $itemName) {
				//list of potential _configpageinit functions
				$initfuncname = $key . '_' . $itemKey . '_configpageinit';
				if ( function_exists($initfuncname) ) {
					$configpageinits[] = $initfuncname;
				}
			}
		}
		//check for module level (rather than item as above) _configpageinit function
		$initfuncname = $key . '_configpageinit';
		if ( function_exists($initfuncname) ) {
			$configpageinits[] = $initfuncname;
		}
	}
}

// extensions vs device/users ... this is a bad design, but hey, it works
if (isset($amp_conf["AMPEXTENSIONS"]) && ($amp_conf["AMPEXTENSIONS"] == "deviceanduser")) {
	unset($fpbx_menu["extensions"]);
} else {
	unset($fpbx_menu["devices"]);
	unset($fpbx_menu["users"]);
}


// Here we process the action and create the exten, mailbox or delete it.
//

$EXTEN_REQUEST = array (
	'actions' => $actions,
	'ext' => $exten,
	'displayname' => $new_name,
	'emergencycid' => '',
	'outboundcid' => $new_outboundcid,
	'accountcode' => '',
	'dtmfmode' => 'auto',
	'devicesecret' => $new_sip_secret,
	'directdid' => $new_directdid,
	);

$actions = explode('/',$EXTEN_REQUEST['actions']);

	$actions_taken = false;

	$ext = '';
	$pass = '';
	$displayname = '';
	$emergencycid = '';
	$outboundcid = '';
	$directdid = '';
	$mailbox = '';
	$tech = 'sip';
	$dcontext = 'from-internal';
	$dtmfmode = 'auto';

	foreach ($EXTEN_REQUEST as $key => $value) {
		switch ($key) {
			case 'ext':
			case 'displayname':
			case 'emergencycid':
			case 'outboundcid':
			case 'accountcode':
			case 'dtmfmode':
			case 'devicesecret':
			case 'directdid':
			case 'mailbox':
			case 'dcontext':
				$$key = $value;
				break;

			default:
				break;
		}
	}

	/*
	echo "\nDumping core_users_get:";
	$user_list = core_users_get($ext);
	var_dump($user_list);

	echo "\nDumping core_devices_get:";
	$device_list = core_devices_get($ext);
	var_dump($device_list);

	echo "\nDumping voicemail_mailbox_get:";
	$vm_list = voicemail_mailbox_get($ext);
	var_dump($vm_list);

	exit;
	*/

	if ($ext == '') {
		fatal("No Extension provided (this should have been caught above, may be a bug");
		exit (10);
	}

	/* DEFAULTS:
	   displayname:  ext 
	   devicesecret: ext 
	 */

	if (in_array('addext', $actions) || in_array('addvm',$actions)) {
		if ($displayname == '') {
			$displayname = $ext;
		}
		if (isset($accountcode)) {
			$_REQUEST['devinfo_accountcode'] = $accountcode;
		}
		if (!isset($devicesecret)) {
			$devicesecret = $ext;
		}
		if ($mailbox == '') {
			$mailbox = $ext.'@default';
		}
		$user_add_arr = array(
			'extension' => $ext,
			'device' => $ext,
			'name' => $displayname,
			'directdid' => $directdid,
			'outboundcid' => $outboundcid,
			'sipname' => '',
			'record_out' => 'Never',
			'record_in' => 'Never',
			'callwaiting' => 'enabled',

			'vm' => 'enabled',
			'vmcontext' => 'default',
			'options' => '',
			'vmpwd' => $new_vm_password,
			'email' => '',
			'pager' => '',
			'attach' => 'attach=no',
			'saycid' => 'saycid=no',
			'envelope' => 'envelope=no',
			'delete' => 'delete=no',
		);

		// archaic code expects these in the REQUEST array ...
		//
		$_REQUEST['devinfo_secret'] = $devicesecret;
		$_REQUEST['devinfo_dtmfmode'] = $dtmfmode;
		$_REQUEST['devinfo_canreinvite'] = 'no';
		$_REQUEST['devinfo_context'] = $dcontext;
		$_REQUEST['devinfo_host'] = 'dynamic';
		$_REQUEST['devinfo_type'] = 'friend';
		$_REQUEST['devinfo_nat'] = 'yes';
		$_REQUEST['devinfo_port'] = '5060';
		$_REQUEST['devinfo_dial'] = 'SIP/'.$ext;
		$_REQUEST['devinfo_mailbox'] = $mailbox;

	} else if (in_array('modext', $actions)) {
		$user_list = core_users_get($ext);
		//var_dump($user_list);
		if (!isset($user_list['extension'])) {
			error("No such extension found: $ext");
			exit (10);
		}
		$device_list = core_devices_get($ext);
		//var_dump($device_list);
		if (count($device_list) == 0) {
			error("No such device found: $ext");
			exit (10);
		}
		$vm_list = voicemail_mailbox_get($ext);
		//var_dump($vm_list);
		if (count($vm_list) == 0) {
			error("No voicemail found for: $ext");
			exit (10);
		}

		if ($param_name) {
			$user_list['name'] = $new_name;
			$device_list['description'] = $new_name;
			$vm_list['name'] = $new_name;
		}
		if ($param_sip_secret) {
			$device_list['secret'] = $new_sip_secret;
		}
		if ($param_vm_password) {
			$vm_list['pwd'] = $new_vm_password;
		}
		if ($param_directdid) {
			$user_list['directdid'] = $new_directdid;
		}
		if ($param_outboundcid) {
			$user_list['outboundcid'] = $new_outboundcid;
		}
		$user_mod_arr = array(
			'extension' => $ext,
			'device' => $ext,
			'name' => $user_list['name'],
			'directdid' => $user_list['directdid'],
			'outboundcid' => $user_list['outboundcid'],
			'sipname' => $user_list['sipname'],
			'record_out' => $user_list['record_out'],
			'record_in' => $user_list['record_in'],
			'callwaiting' => $user_list['callwaiting'],

			'vm' => 'enabled',
			'vmcontext' => $vm_list['vmcontext'],
			'vmpwd' => $vm_list['pwd'],
			'email' => $vm_list['email'],
			'pager' => $vm_list['pager'],
			'options' => '',
			'attach' => $vm_list['options']['attach'],
			'saycid' => $vm_list['options']['saycid'],
			'envelope' => $vm_list['options']['envelope'],
			'delete' => $vm_list['options']['delete'],
		);

		// archaic code expects these in the REQUEST array ...
		//
		$_REQUEST['devinfo_secret'] = $device_list['secret'];
		$_REQUEST['devinfo_dtmfmode'] = $device_list['dtmfmode'];
		$_REQUEST['devinfo_canreinvite'] = $device_list['canreinvite'];
		$_REQUEST['devinfo_context'] = $device_list['context'];
		$_REQUEST['devinfo_host'] = $device_list['host'];
		$_REQUEST['devinfo_type'] = $device_list['type'];
		$_REQUEST['devinfo_nat'] = $device_list['nat'];
		$_REQUEST['devinfo_port'] = $device_list['port'];
		$_REQUEST['devinfo_dial'] = $device_list['dial'];
		$_REQUEST['devinfo_mailbox'] = $device_list['mailbox'];
		$_REQUEST['devinfo_accountcode'] = $device_list['accountcode'];
		$_REQUEST['devinfo_username'] = $ext;
		//$_REQUEST['devinfo_callerid'] = $device_list['callerid'];
		//$_REQUEST['devinfo_record_in'] = $device_list['record_in'];
		//$_REQUEST['devinfo_record_out'] = $device_list['record_out'];

		if (isset($device_list['qualify'])) { 
			$_REQUEST['devinfo_qualify'] = $device_list['qualify'];
		}
		if (isset($device_list['callgroup'])) { 
			$_REQUEST['devinfo_callgroup'] = $device_list['callgroup'];
		}
		if (isset($device_list['pickupgroup'])) { 
			$_REQUEST['devinfo_pickupgroup'] = $device_list['pickupgroup'];
		}
		if (isset($device_list['allow'])) { 
			$_REQUEST['devinfo_allow'] = $device_list['allow'];
		}
		if (isset($device_list['disallow'])) { 
			$_REQUEST['devinfo_disallow'] = $device_list['disallow'];
		}

		$actions_taken = true;
		debug("core_users_edit($ext, $user_add_arr)");
		core_users_edit($ext, $user_mod_arr);
		// doesn't return a return code, so hope it worked:-)

		debug("core_devices_del($ext, true)");
		debug("core_devices_add($ext,'sip',".$device_list['dial'].",'fixed',$ext,".$device_list['description'].",".$device_list['emergency_cid'].",true)");
		core_devices_del($ext,true);
		core_devices_add($ext,'sip',$device_list['dial'],'fixed',$ext,$device_list['description'],$device_list['emergency_cid'],true);
		// doesn't return a return code, so hope it worked:-)

		debug("voicemail_mailbox_del($ext)");
		debug("voicemail_mailbox_add($ext, $user_mod_arr)");
		voicemail_mailbox_del($ext);
		voicemail_mailbox_add($ext, $user_mod_arr);
	}

	if (in_array('addvm', $actions)) {
		$actions_taken = true;
		if (($existing_vmbox = voicemail_mailbox_get($ext)) == null ) {
			debug("voicemail_mailbox_add($ext, $user_add_arr)");
			voicemail_mailbox_add($ext, $user_add_arr);
		} else {
			debug(print_r($existing_vmbox,true));
			fatal("voicemail_mailbox_get($ext) indicates the box already exists, aborting");
			exit (1);
		}

		// check if we need to create symlink if if addext is not being called
		if (!in_array('addext', $actions)) {

			$thisUser = core_users_get($ext);

			// This is a bit kludgey, the other way is to reformat the core_users_get() info and do a core_users_add() in edit mode
			//
			if (!empty($thisUser)) {
				$this_vmcontext = $user_add_arr['vmcontext'];
				sql("UPDATE `users` SET `voicemail` = '$this_vmcontext' WHERE `extension` = '$ext'");

				if ($astman) {
					$astman->database_put("AMPUSER",$ext."/voicemail","\"".isset($this_vmcontext)?$this_vmcontext:''."\"");
				}
			}

			if(isset($this_vmcontext) && $this_vmcontext != "novm") {
				if(empty($this_vmcontext)) {
					$vmcontext = "default";
				} else {
					$vmcontext = $this_vmcontext;
				}
				//voicemail symlink
				//
				exec("rm -f /var/spool/asterisk/voicemail/device/".$ext,$output,$return_val);
				exec("/bin/ln -s /var/spool/asterisk/voicemail/".$vmcontext."/".$ext."/ /var/spool/asterisk/voicemail/device/".$ext,$output,$return_val);
				if ($return_val != 0) {
					error("Error code $return_val when sym-linking vmail context $vmcontext to device directory for $ext. Trying to carry on but you should investigate.");
				}
			}
		}
	}

	if (in_array('addext', $actions)) {
		$actions_taken = true;
		$any_users = core_users_get($ext);
		debug("core_users_add($user_add_arr)");
		if (isset($any_users['extension']) || !core_users_add($user_add_arr)) {
			var_dump($any_users);
			fatal("Attempt to add user failed, aborting");
			exit (1);
		}
	}

	if (in_array('addext', $actions)) {
		$actions_taken = true;
		debug("core_devices_add($ext, $tech, '', 'fixed', $ext, $displayname, $emergencycid)");
		$any_devices = core_devices_get($ext);
		if (count($any_devices) > 0 || !core_devices_add($ext, $tech, '', 'fixed', $ext, $displayname, $emergencycid)) {
			var_dump($any_devices);
			fatal("Attempt to add device failed, aborting");
			exit (1);
		}
	}

	if (in_array('remext', $actions)) {
		$actions_taken = true;
		if (core_users_get($ext) != null) {
			debug("removing user $ext");
			core_users_del($ext);
			core_devices_del($ext);
		} else {
			debug("not removing user $ext");
		}
		if (voicemail_mailbox_get($ext) != null) {
			debug("removing vm $ext");
			voicemail_mailbox_del($ext);
		} else {
			debug("not removing vm $ext");
		}
	}

	if ($actions_taken) {
		debug("Request completed successfully");
		exit (0);
	} else {
		warning("No actions were performed");
		exit (10);
	}
	exit;
?>
