#!/usr/bin/php -q
<?php
/*
 +-------------------------------------------------------------------------+
 | Copyright (C) 2015 Freeside Internet Services                           |
 |                                                                         |
 | This program is free software; you can redistribute it and/or           |
 | modify it under the terms of the GNU General Public License             |
 | as published by the Free Software Foundation; either version 2          |
 | of the License, or (at your option) any later version.                  |
 |                                                                         |
 | This program is distributed in the hope that it will be useful,         |
 | but WITHOUT ANY WARRANTY; without even the implied warranty of          |
 | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           |
 | GNU General Public License for more details.                            |
 +-------------------------------------------------------------------------+
 | Copy this file to the cli directory of your Cacti installation, which   |
 | should also contain an add_device.php script.  Give this file the same  |
 | permissions as add_device.php, and configure your Freeside installation |
 | with the location of that directory and the name of a user who has      |
 | permission to read these files.  See the FS::part_export::cacti docs    |
 | for more details.                                                       |
 +-------------------------------------------------------------------------+
*/

/* do NOT run this script through a web browser */
if (!isset($_SERVER["argv"][0]) || isset($_SERVER['REQUEST_METHOD'])  || isset($_SERVER['REMOTE_ADDR'])) {
	die("<br><strong>This script is only meant to run at the command line.</strong>");
}

/* We are not talking to the browser */
$no_http_headers = true;

/* 
Currently, only drop-device is actually being used by Freeside integration,
but keeping commented out code for potential future development.
*/

include(dirname(__FILE__)."/../site/include/global.php");
include_once($config["base_path"]."/lib/api_device.php");

/*
include_once($config["base_path"]."/lib/api_automation_tools.php");
include_once($config["base_path"]."/lib/api_data_source.php");
include_once($config["base_path"]."/lib/api_graph.php");
include_once($config["base_path"]."/lib/functions.php");
*/

/* process calling arguments */
$action = '';
$ip = '';
$host_template = '';
// $delete_graphs = FALSE;
$parms = $_SERVER["argv"];
array_shift($parms);
if (sizeof($parms)) {
	foreach($parms as $parameter) {
		@list($arg, $value) = @explode("=", $parameter);
		switch ($arg) {
        case "--drop-device":
			$action = 'drop-device';
            break;
/*
        case "--get-device":
			$action = 'get-device';
            break;
        case "--get-graph-templates":
			$action = 'get-graph-templates';
            break;
*/
		case "--ip":
			$ip = trim($value);
			break;
		case "--host-template":
			$host_template = trim($value);
			break;
/*
		case "--delete-graphs":
			$delete_graphs = TRUE;
			break;
*/
		case "--version":
		case "-V":
		case "-H":
		case "--help":
			die(default_die());
		default:
			die("ERROR: Invalid Argument: ($arg)");
		}
	}
} else {
  die(default_die());
}

/* Now take an action */
switch ($action) {
case "drop-device":
	$host_id = host_id($ip);
/*
	if ($delete_graphs) {
		// code copied & pasted from version 0.8.8a
        // cacti/site/lib/host.php and cacti/site/graphs.php 
		// unfortunately no api function for this yet
		$graphs = db_fetch_assoc("select
			graph_local.id as local_graph_id
			from graph_local
			where graph_local.host_id=" . $host_id);
		if (sizeof($graphs) > 0) {
			foreach ($graphs as $graph) {
				$data_sources = array_rekey(db_fetch_assoc("SELECT data_template_data.local_data_id
					FROM (data_template_rrd, data_template_data, graph_templates_item)
					WHERE graph_templates_item.task_item_id=data_template_rrd.id
					AND data_template_rrd.local_data_id=data_template_data.local_data_id
					AND graph_templates_item.local_graph_id=" . $graph["local_graph_id"] . "
					AND data_template_data.local_data_id > 0"), "local_data_id", "local_data_id");
				if (sizeof($data_sources)) {
					api_data_source_remove_multi($data_sources);
				}
				api_graph_remove($graph["local_graph_id"]);
			}
		}
	}
*/
	api_device_remove($host_id);
	if (host_id($ip,1)) {
		die("Failed to remove hostname $ip");
	}
	exit(0);
/*
case "get-device":
	echo host_id($ip);
	exit(0);
case "get-graph-templates":
	if (!$host_template) {
		die("No host template specified");
	}
	$graphs = getGraphTemplatesByHostTemplate($host_template);
	if (sizeof($graphs)) {
		foreach (array_keys($graphs) as $gtid) {
			echo $gtid . "\n";
		}
		exit(0);
	}
	die("No graph templates associated with this host template");
*/
default:
	die("Specified action not found, contact a developer");
}

function default_die() {
  return "Cacti interface for freeside.  Do not use for anything else.";
}

function host_id($ip_address, $nodie=0) {
	if (!$ip_address) {
		die("No hostname specified");
	}
	$devices = array();
	$query = "select id from host";
	$query .= " where hostname='$ip_address'";
	$devices = db_fetch_assoc($query);
	if (sizeof($devices) > 1) {
        // This should never happen, just being thorough
		die("Multiple devices found for hostname $ip_address");
	} else if (!sizeof($devices)) {
		if ($nodie) {
			return '';
		} else {
			die("Could not find hostname $ip_address");
		}
	}
	return $devices[0]['id'];
}

?>
