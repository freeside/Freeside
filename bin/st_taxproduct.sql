--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

--
-- Data for Name: part_pkg_taxproduct; Type: TABLE DATA; Schema: public; Owner: freeside
--

COPY part_pkg_taxproduct (taxproductnum, data_vendor, taxproduct, description, note) FROM stdin;
1123	suretax	050105	VoIP Services:Usage-Based Charges - Fixed VOIP Service	
1124	suretax	010201	Long Distance:800 Number Service	
1125	suretax	210110	Computer Services:Sale of Custom Software	
1126	suretax	050213	VoIP Services:IP Centrex Line	
1127	suretax	060101	Internet:Recurring Internet Access Charges	
1128	suretax	980404	Leasing:Lease Contract - 30 Days - Stream	
1129	suretax	210501	Computer Services:Customize Canned Apps	
1130	suretax	360101	Dark Fiber:Lease of Dark Fiber to a Reseller	
1131	suretax	110503	Misc Telecom Charges:Conference Bridging - Stand-Alone - Intrastate	
1132	suretax	110604	Misc Telecom Charges:Customer Account Set-up Fee	
1133	suretax	110504	Misc Telecom Charges:Conference Bridging - Stand-Alone - Interstate	
1134	suretax	050216	VoIP Services:SIP Trunk - High Capacity	
1135	suretax	050110	VoIP Services:Activation/Deactivation Charges	
1136	suretax	310205	Digital Goods:Digital Books - Access Only	
1137	suretax	210114	Computer Services:Sale of Canned Software Via Download	
1138	suretax	310106	Digital Goods:Emailed Information Service	
1139	suretax	210164	Computer Services:Colocation - Other	
1140	suretax	180104	Cable Services:Rental Charges - Converter Boxes	
1141	suretax	110607	Misc Telecom Charges:Returned Check Fee	
1142	suretax	920101	Maintenance Contracts:Optional Contract	
1143	suretax	020212	Local Services:Centrex Line - Recurring	
1144	suretax	050115	VoIP Services:SIP Trunk - Standard	
1145	suretax	020209	Local Services:Trunk Line DOD & DID/DOD	
1146	suretax	050113	VoIP Services:IP Centrex Line	
1147	suretax	980403	Leasing:Lease Contract - 30 Days - Inception	
1148	suretax	100103	Paging:One-Way Paging - Airtime/Usage Charges	
1149	suretax	040104	Prepaid Wireless / Cellular:Usage / Airtime Charges	
1150	suretax	999999	General Sales:Tax Exempt Products and Services	
1151	suretax	400303	Utilities:Solar Energy - Facility Purchase	
1152	suretax	070261	Private Line:Data - Line Charge - Interstate (100% allocation)	
1153	suretax	070262	Private Line:Data - Channel Termination Point (Local Loop) - Interstate (100% allocation)	
1154	suretax	070263	Private Line:Data - Connection/Disconnection - Interstate  (100% allocation)	
1155	suretax	070264	Private Line:Data - Service Charge - Non-Recurring - Interstate  (100% allocation)	
1156	suretax	990102	General Sales:Consumers Use Tax	
1157	suretax	310102	Digital Goods:Online Information Services	
1158	suretax	920106	Maintenance Contracts:Extended Warranty	
1159	suretax	100203	Paging:Two -Way Paging - Airtime/Usage Charges	
1160	suretax	070101	Private Line:Voice - Line Charge - Intrastate Intracity	
1161	suretax	400402	Utilities:Other Transition Charges	
1162	suretax	010101	Long Distance:Toll	
1163	suretax	010107	Long Distance:Toll - Federal Taxes only	
1164	suretax	010202	Long Distance:800 Service - Connection/Disconnection Charge	
1165	suretax	010203	Long Distance:800 Service - Basic Service Charges - Recurring	
1166	suretax	010204	Long Distance:800 Service - Basic Service Charges - Amount Attributable To Intrastate - Recurring	
1167	suretax	930201	Repair/Maintenance:TPP - Labor Only	
1168	suretax	010205	Long Distance:800 Service - Basic Service Charges - Amount Attributable To Interstate - Recurring	
1169	suretax	010257	Long Distance:800 Number Service - Intrastate	
1170	suretax	010258	Long Distance:800 Number Service - Interstate	
1171	suretax	010301	Long Distance:900 Service - Local Pay Per Call Service - Transmission & Information Service	
1172	suretax	010302	Long Distance:900 Service - Local Pay Per Call Service - Amount Attributable To Transmission	
1173	suretax	010303	Long Distance:900 Service - Local Pay Per Call Service - Amount Attributable To Information Service	
1174	suretax	010304	Long Distance:900 Service - Intrastate - Transmission & Information Service	
1175	suretax	010305	Long Distance:900 Service - Intrastate - Amount Attributable To Transmission	
1176	suretax	010306	Long Distance:900 Service - Intrastate - Amount Attributable To Information Service	
1177	suretax	010401	Long Distance:Service Plan - Fee	
1178	suretax	010402	Long Distance:Service Plan - Connection/Disconnection Charges - Non-Recurring	
1179	suretax	010403	Long Distance:Service Plan - Service Charges- Intra/Interstate Plan - Recurring	
1180	suretax	010404	Long Distance:Service Plan - Service Charges - Intrastate Plan - Recurring	
1181	suretax	010405	Long Distance:Service Plan - Service Charges - Interstate Plan -Recurring	
1182	suretax	010406	Long Distance:Service Plan - Service Charges - Intra/Interstate Plan - Amount Attributable To Intrastate - Recurring	
1183	suretax	010407	Long Distance:Service Plan - Service Charges - Intra/Interstate Plan - Amount Attributable To Interstate - Recurring	
1184	suretax	050215	VoIP Services:SIP Trunk - Standard	
1185	suretax	010408	Long Distance:Service Plan - Service Charges - International Plan - Recurring	
1186	suretax	010409	Long Distance:Service Plan - Service Charges - Unlimited Long Distance Calling Plan - Amount Attributable To International	
1187	suretax	020101	Local Services:Local Toll Calls	
1188	suretax	020102	Local Services:Local Unit-Based Calls	
1189	suretax	020201	Local Services:Standard Line - Recurring Charge	
1190	suretax	020202	Local Services:Activation/Deactivation Charge for a Vertical Feature (Call Waiting/Call Forwarding)	
1191	suretax	020203	Local Services:Recurring Service Charge for a Vertical Feature (Call Waiting/Call Forwarding)	
1192	suretax	020204	Local Services:Usage Charge for a Vertical Feature (Call Waiting/Call Forwarding)	
1193	suretax	180103	Cable Services:Pay-Per-View Programming - Non-Recurring	
1194	suretax	020205	Local Services:Connection/Disconnection Charge - Non-Recurring	
1195	suretax	020206	Local Services:Local Calling Area Charge - Recurring	
1196	suretax	020207	Local Services:Standard Line - Pro-Rated Charge When Converting from Another Carrier	
1197	suretax	020208	Local Services:Trunk Line DID	
1198	suretax	020210	Local Services:Co-Located Trunk Line DID in Central Office	
1199	suretax	020211	Local Services:Co-Located Trunk DOD & DID/DODin Central Office	
1200	suretax	020213	Local Services:High-Capacity Trunk Line - Recurring Charge - 1.5MB T-1	
1201	suretax	020214	Local Services:High-Capacity Trunk Line - Recurring Charge - ISDN-PRI	
1202	suretax	020215	Local Services:High-Capacity Trunk Line - Recurring Charge - DID Only	
1203	suretax	020216	Local Services:High-Capacity Trunk Line -ISDN - PRI - DID Only	
1204	suretax	020217	Local Services:Centrex Service - Accessory Features	
1205	suretax	020301	Local Services:Bundled Service Plan - Local/Long Distance Service Plan - Recurring	
1206	suretax	020302	Local Services:Bundled Service Plan - Amount Attributable to Local Basic Service	
1207	suretax	020303	Local Services:Bundled Service Plan - Vertical Features Charge	
1208	suretax	070116	Private Line:Voice - Connection/Disconnection - Intrastate Intracity	
1209	suretax	020304	Local Services:Bundled Service Plan - Amount Attributable to Local Non-Basic Service	
1210	suretax	030101	Cellular Services:Cellular Service - Monthly Chg - Basic Service Charges (Recurring)	
1211	suretax	030102	Cellular Services:Cellular Service - Monthly Chg - Other Service Charges (Recurring)	
1212	suretax	030103	Cellular Services:Cellular Service - Monthly Chg - Other Service Charges (Non-Recurring)	
1213	suretax	030104	Cellular Services:Cellular Service - Monthly Chg - Vertical Features (Call Waiting/Call Forwarding Etc.) - Activation/Deactivation (Non - Recurring)	
1214	suretax	030105	Cellular Services:Cellular Service - Monthly Chg - Vertical Features (Call Waiting/Call Forwarding Etc.) - Service Charges (Recurring)	
1215	suretax	110507	Misc Telecom Charges:Conference Bridging - Stand-Alone - International	
1216	suretax	030106	Cellular Services:Cellular Service - Monthly Chg - Vertical Features (Call Waiting/Call Forwarding Etc.) - Usage	
1217	suretax	030107	Cellular Services:Cellular Service - Monthly Chg - Activation/Deactivation Charges (Non-Recurring)	
1218	suretax	030108	Cellular Services:Cellular Service - Monthly Chg - Cellular Local-Only Calling Plan - Basic Service Charges	
1219	suretax	030109	Cellular Services:Cellular Service - Airtime Undetermined	
1220	suretax	030111	Cellular Services:Cellular Service - Airtime Intrastate - Call Org or Term in City of Primary Use	
1221	suretax	030112	Cellular Services:Cellular Service - Airtime Intrastate - Call Org or Term in State of Primary Use	
1222	suretax	050214	VoIP Services:Fax Over IP - Nomadic VoIP Service	
1223	suretax	030113	Cellular Services:Cellular Service - Airtime Intrastate - Call Org or Term in State Other than State of Primary Use	
1224	suretax	030114	Cellular Services:Cellular Service - Airtime Interstate - Call Org or Term in City of Primary Use	
1225	suretax	030115	Cellular Services:Cellular Service - Airtime Interstate - Call Org or Term in State of Primary Use	
1226	suretax	030116	Cellular Services:Cellular Service - Airtime Interstate - Call Org or Term in State Other than State of Primary Use	
1227	suretax	030201	Cellular Services:Cellular Service - Toll Charges - Airtime Undetermined	
1228	suretax	040101	Prepaid Wireless / Cellular:Monthly Service Charge - Recurring	
1229	suretax	040102	Prepaid Wireless / Cellular:Authorization Code - Denominated in Dollars	
1230	suretax	040103	Prepaid Wireless / Cellular:Re-Charge - Denominated in Dollars	
1231	suretax	040105	Prepaid Wireless / Cellular:Phone Card - Denominated in Dollars	
1232	suretax	040106	Prepaid Wireless / Cellular:Initial Set-up Charge	
1233	suretax	040107	Prepaid Wireless / Cellular:Phone Card - Denominated in Minutes	
1234	suretax	040108	Prepaid Wireless / Cellular:Authorization Code - Denominated in Minutes	
1235	suretax	040109	Prepaid Wireless / Cellular:Recharge - Denominated in Minutes	
1236	suretax	040201	Prepaid Wireless / Cellular:Wholesale - Sale of Phone Card - Intrastate/Interstate	
1237	suretax	040202	Prepaid Wireless / Cellular:Wholesale - Sale of Phone Card - Amount Attributable to Intrastate	
1238	suretax	040203	Prepaid Wireless / Cellular:Wholesale - Sale of Phone Card - Amount Attributable to Interstate	
1239	suretax	040204	Prepaid Wireless / Cellular:Wholesale - Unit Based Monthly Access Charges	
1240	suretax	040301	Prepaid Wireless / Cellular:Retail - Sale of Phone Card - Intrastate/Interstate	
1241	suretax	040302	Prepaid Wireless / Cellular:Retail - Sale of Phone Card - Amount Attributable to Intrastate	
1242	suretax	040303	Prepaid Wireless / Cellular:Retail - Sale of Phone Card - Amount Attributable to Interstate	
1243	suretax	040304	Prepaid Wireless / Cellular:Retail - Unit Based Monthly Access Charges	
1244	suretax	040401	Prepaid Wireless / Cellular:Prepaid Wireless Retailer - Phone Card - Denominated in Dollars	
1245	suretax	040402	Prepaid Wireless / Cellular:Prepaid Wireless Retailer - Phone Card - Denominated in Minutes	
1246	suretax	050101	VoIP Services:Basic Service Charges - Fixed VOIP Service	
1247	suretax	050102	VoIP Services:VOIP Monthly Charge - Amount Attributable To Local Service	
1248	suretax	050103	VoIP Services:VOIP Monthly Charge - Amount Attributable To Intrastate Toll Service	
1249	suretax	050104	VoIP Services:VOIP Monthly Charge - Amount Attributable To Interstate Toll Service	
1250	suretax	050112	VoIP Services:VOIP-Enabled Vertical Features	
1251	suretax	050114	VoIP Services:Fax Over IP - Fixed VoIP Service	
1252	suretax	050116	VoIP Services:SIP Trunk - High Capacity	
1253	suretax	400202	Utilities:Natural Gas - Actual Energy	
1254	suretax	050117	VoIP Services:Non-Interconnected VoIP - Usage Based Charges (Undetermined) - Fixed VoIP Service	
1255	suretax	050155	VoIP Services:Usage-Based Charges - Fixed VOIP Service	
1256	suretax	110801	Misc Telecom Charges:Payphone Access Line	
1257	suretax	050158	VoIP Services:Usage-Based Charges - Fixed VOIP Service - Interstate / International	
1258	suretax	050201	VoIP Services:Basic Service Charges - Nomadic VOIP Service	
1259	suretax	050202	VoIP Services:VOIP Monthly Charge - Amount Attributable To Local Service	
1260	suretax	050203	VoIP Services:VOIP Monthly Charge - Amount Attributable To Intrastate Toll Service	
1261	suretax	050204	VoIP Services:VOIP Monthly Charge - Amount Attributable To Interstate Toll Service	
1262	suretax	050205	VoIP Services:Usage-Based Charges - Nomadic VOIP Service	
1263	suretax	050210	VoIP Services:Activation/Deactivation Charges	
1264	suretax	050212	VoIP Services:VOIP-Enabled Vertical Features	
1265	suretax	050217	VoIP Services:Non-Interconnected VoIP - Usage Based Charges (Undetermined) - Nomadic VoIP Service	
1266	suretax	050255	VoIP Services:Usage-Based Charges - Nomadic VOIP Service - Undetermined	
1267	suretax	050256	VoIP Services:Usage-Based Charges - Nomadic VOIP Service - Local	
1268	suretax	050257	VoIP Services:Usage-Based Charges - Nomadic VOIP Service - Intrastate	
1269	suretax	050258	VoIP Services:Usage-Based Charges - Nomadic VOIP Service - Interstate / International	
1270	suretax	050401	VoIP Services:Wireless VOIP Monthly Service Charge	
1271	suretax	050402	VoIP Services:Wireless VOIP - Monthly Service Charge - Amount Attributable To Local Service	
1272	suretax	050403	VoIP Services:Wireless VOIP - Monthly Service Charge - Amount Attributable To Intrastate Toll Service	
1273	suretax	050404	VoIP Services:Wireless VOIP - Monthly Service Charge - Amount Attributable To Interstate Toll Service	
1274	suretax	050405	VoIP Services:Wireless VOIP - Activation / Deactivation Charges	
1275	suretax	050406	VoIP Services:Wireless VOIP - Vertical Features Charges	
1276	suretax	060102	Internet:Broadband Transmission Charges	
1277	suretax	070102	Private Line:Voice - Line Charge - Intrastate Intercity  IntraLATA	
1278	suretax	070103	Private Line:Voice - Line Charge - Intrastate Intercity InterLATA	
1279	suretax	070104	Private Line:Voice - Line Charge - Interstate	
1280	suretax	070109	Private Line:Voice - Channel Termination Point (Local Loop) - Intrastate Intracity	
1281	suretax	070110	Private Line:Voice - Channel Termination Point (Local Loop) - Intrastate Intercity IntraLATA	
1282	suretax	070111	Private Line:Voice - Channel Termination Point (Local Loop) - Intrastate Intercity InterLATA	
1283	suretax	110606	Misc Telecom Charges:Termination Fee	
1284	suretax	070112	Private Line:Voice - Channel Termination Point (Local Loop) - Interstate	
1285	suretax	070117	Private Line:Voice - Connection/Disconnection - Intrastate Intercity IntraLATA	
1286	suretax	070118	Private Line:Voice - Connection/Disconnection - Intrastate Intercity InterLATA	
1287	suretax	070119	Private Line:Voice - Connection/Disconnection - Interstate	
1288	suretax	070123	Private Line:Voice - Service Charge - Non-Recurring - Intrastate Intracity	
1289	suretax	070124	Private Line:Voice - Service Charge - Non-Recurring - Intrastate Intercity IntraLATA	
1290	suretax	070125	Private Line:Voice - Service Charge - Non-Recurring - Intrastate Intercity InterLATA	
1291	suretax	070126	Private Line:Voice - Service Charge - Non-Recurring - Interstate	
1292	suretax	070149	Private Line:Voice - Line Charge - Intrastate Intracity	
1293	suretax	070201	Private Line:Data - Line Charge -  Intrastate Intracity	
1294	suretax	070202	Private Line:Data - Line Charge - Intrastate Intercity  IntraLATA	
1295	suretax	400501	Utilities:Electric - Misc - Connection Fee	
1296	suretax	070203	Private Line:Data - Line Charge - Intrastate Intercity InterLATA	
1297	suretax	070204	Private Line:Data - Line Charge - Interstate	
1298	suretax	070209	Private Line:Data - Channel Termination Point (Local Loop) - Intrastate Intracity	
1299	suretax	110601	Misc Telecom Charges:Unpublished/Unlisted Number Charge	
1300	suretax	070210	Private Line:Data - Channel Termination Point (Local Loop) - Intrastate Intercity IntraLATA	
1301	suretax	070211	Private Line:Data - Channel Termination Point (Local Loop) - Intrastate Intercity InterLATA	
1302	suretax	070212	Private Line:Data - Channel Termination Point (Local Loop) - Interstate	
1303	suretax	070216	Private Line:Data - Connection/Disconnection - Intrastate Intracity	
1304	suretax	070217	Private Line:Data - Connection/Disconnection - Intrastate Intercity IntraLATA	
1305	suretax	070218	Private Line:Data - Connection/Disconnection - Intrastate Intercity InterLATA	
1306	suretax	070219	Private Line:Data - Connection/Disconnection - Interstate	
1307	suretax	070223	Private Line:Data - Service Charge - Non-Recurring - Intrastate Intracity	
1308	suretax	070224	Private Line:Data - Service Charge - Non-Recurring - Intrastate Intercity IntraLATA	
1309	suretax	070225	Private Line:Data - Service Charge - Non-Recurring - Intrastate Intercity InterLATA	
1310	suretax	070226	Private Line:Data - Service Charge - Non-Recurring - Interstate	
1311	suretax	070249	Private Line:Data - Line Charge -  Intrastate Intracity	
1312	suretax	070250	Private Line:Data - Local Loop Connecting To Intrastate Intracity Line	
1313	suretax	070251	Private Line:Data - Connection/Disconnection - Intrastate Intracity	
1314	suretax	080101	Data Lines:Non-PSTN Data Line Non-Private - Intrastate Access Charge - Recurring	
1315	suretax	080102	Data Lines:Non-PSTN Data Line Non-Private - Interstate Access Charge - Recurring	
1316	suretax	080103	Data Lines:Non-PSTN Data Line Non-Private - Usage Charge - Intrastate	
1317	suretax	080104	Data Lines:Non-PSTN Data Line Non-Private - Port Charges - Recurring	
1318	suretax	080105	Data Lines:Non-PSTN Data Line Non-Private - Local Loop Charge - Recurring	
1319	suretax	080106	Data Lines:Non-PSTN Data Line Non-Private - Local Loop Usage Charge	
1320	suretax	080107	Data Lines:Non-PSTN Data Line Non-Private - Connection/Disconnection Charge - Intrastate	
1321	suretax	100205	Paging:Two -Way Paging - Vertical Features - Service Charges - Recurring	
1322	suretax	080108	Data Lines:Non-PSTN Data Line Non-Private - Connection/Disconnection Charge - Interstate	
1323	suretax	080109	Data Lines:Non-PSTN Data Line Non-Private - Service Charge - Intrastate	
1324	suretax	080110	Data Lines:Non-PSTN Data Line Non-Private - Service Charge - Interstate	
1325	suretax	080111	Data Lines:Non-PSTN Data Line Non-Private - Access Charge - Intrastate/Intersrate (Recurring)	
1326	suretax	080112	Data Lines:Non-PSTN Data Line Non-Private - Connection/Disconnection Charge - Intrastate/Interstate	
1327	suretax	110103	Misc Telecom Charges:Voice Mail Service - Usage	
1328	suretax	080113	Data Lines:Non-PSTN Data Line Non-Private - Service Charge - Intrastate/Interstate	
1329	suretax	210116	Computer Services:Licensing of Canned Software Via Internet Download	
1330	suretax	080201	Data Lines:PSTN Data Line Non-Private - Intrastate Access Charges - Recurring	
1331	suretax	080202	Data Lines:PSTN Data Line Non-Private - Interstate Access Charges - Recurring	
1332	suretax	080203	Data Lines:PSTN Data Line Non-Private - Usage Charges	
1333	suretax	080204	Data Lines:PSTN Data Line Non-Private - Connection/Disconnection Charge - Non-Recurring	
1334	suretax	080205	Data Lines:PSTN Data Line Non-Private - Service Charges - Non-Recurring	
1335	suretax	080206	Data Lines:PSTN Data Line Non-Private - Access Charges - Primary Rate Interface ISDN Line - Intrastate - Recurring	
1336	suretax	080207	Data Lines:PSTN Data Line Non-Private - Intra/Interstate Access Charges - Recurring	
1337	suretax	090101	Wireless Data Services:Non-PSTN Wireless Data Service - Basic Service Charge - Recurring	
1338	suretax	090102	Wireless Data Services:Non-PSTN Wireless Data Service - Activation/Deactivation Charge - Non-Recurring	
1339	suretax	110602	Misc Telecom Charges:Additional Directory Listing Charge	
1340	suretax	090103	Wireless Data Services:Non-PSTN Wireless Data Service -Data Transmission - Usage-Based Charges	
1341	suretax	090104	Wireless Data Services:Non-PSTN Wireless Data Service - Wireless E-Mail Services	
1342	suretax	090201	Wireless Data Services:PSTN Wireless Data Service - Basic Service Charge - Recurring	
1343	suretax	110603	Misc Telecom Charges:Detailed Billing / Invoice Fee	
1344	suretax	090202	Wireless Data Services:PSTN Wireless Data Service - Activation/Deactivation Charge - Non-Recurring	
1345	suretax	090203	Wireless Data Services:PSTN Wireless Data Service -Data Transmission - Usage-Based Charges	
1346	suretax	090204	Wireless Data Services:PSTN Wireless Data Service - Wireless E-Mail Services	
1347	suretax	100101	Paging:One-Way Paging - Activation/Deactivation Fee - Non-Recurring	
1348	suretax	100102	Paging:One-Way Paging - Basic Service Charges - Recurring	
1349	suretax	100104	Paging:One-Way Paging - Vertical Features - Activation/Deactivation Fee - Non-Recurring	
1350	suretax	100105	Paging:One-Way Paging - Vertical Features - Service Charges - Recurring	
1351	suretax	100106	Paging:One-Way Paging - Vertical Features - Usage	
1352	suretax	110605	Misc Telecom Charges:Expedite / Rush Processing Fee	
1353	suretax	100107	Paging:One-Way Paging - Basic Service Charges Attributable to Intrastate - Recurring	
1354	suretax	100108	Paging:One-Way Paging - Basic Service Charges Attributable to Interstate - Recurring	
1355	suretax	180101	Cable Services:Monthly Basic Service Charges - Recurring	
1356	suretax	100109	Paging:One-Way Paging - Airtime/Usage - Place of Primary Use is a Service Address in the State	
1357	suretax	100201	Paging:Two-Way Paging - Activation/Deactivation Charge - Non-recurring	
1358	suretax	100202	Paging:Two -Way Paging - Basic Service Charges - Recurring	
1359	suretax	100204	Paging:Two -Way Paging - Vertical Features - Activation/Deactivation Fee - Non-Recurring	
1360	suretax	100206	Paging:Two -Way Paging - Vertical Features - Usage	
1361	suretax	100207	Paging:Two -Way Paging - Basic Service Charges Attributable to Intrastate - Recurring	
1362	suretax	100208	Paging:Two -Way Paging - Basic Service Charges Attributable to Interstate - Recurring	
1363	suretax	100209	Paging:Two -Way Paging - Airtime/Usage - Place of Primary Use is a Service Address in the State	
1364	suretax	110101	Misc Telecom Charges:Voice Mail Service - Activation/Deactivation Charge	
1365	suretax	110102	Misc Telecom Charges:Voice Mail Service - Basic Service Charge - Recurring	
1366	suretax	110201	Misc Telecom Charges:Installation - Telecom - Labor Separately Stated On Invoice	
1367	suretax	110202	Misc Telecom Charges:Installation - Telecom - Labor - Lump Sum Bill with Equipment	
1368	suretax	110301	Misc Telecom Charges:Directory Assistance - Local Usage	
1369	suretax	110302	Misc Telecom Charges:Directory Assistance - Long Distance Usage	
1370	suretax	110352	Misc Telecom Charges:Directory Assistance - Long Distance Usage - Interstate / International	
1371	suretax	110401	Misc Telecom Charges:Telecom Equipment Leasing - Used with a Local Service - Lease Term in Excess of 30 Days	
1372	suretax	110402	Misc Telecom Charges:Telecom Equipment Leasing - Not Used with a Local Service - Lease Term in Excess of 30 Days	
1373	suretax	110403	Misc Telecom Charges:Telecom Equipment Leasing - Used with Local Service and Private System - Lease Term in Excess of 30 Days	
1374	suretax	110404	Misc Telecom Charges:Non-Telecom Equipment - Lease Term in Excess of 30 Days	
1375	suretax	110501	Misc Telecom Charges:Conference Bridging - with Transmission - Intrastate	
1376	suretax	110502	Misc Telecom Charges:Conference Bridging - with Transmission - Interstate	
1377	suretax	120101	Telecom Fees:FCC Fee - Subscriber Line Charge	
1378	suretax	120102	Telecom Fees:FCC Fee - PICC Fee - Long Distance Carrier Charge	
1379	suretax	120103	Telecom Fees:FCC Fee - Local Number Portability Charge	
1380	suretax	140101	Wireless Enhanced Services:Cellular Ringtones Charge	
1381	suretax	140102	Wireless Enhanced Services:Information Alerts Charge	
1382	suretax	140103	Wireless Enhanced Services:Digitized Media Fee - Access Only	
1383	suretax	140104	Wireless Enhanced Services:Digitized Media Fee - Downloads	
1384	suretax	140105	Wireless Enhanced Services:Electronic Games Fee - Access Only	
1385	suretax	140106	Wireless Enhanced Services:Electronic Games Fee - Downloads	
1386	suretax	140107	Wireless Enhanced Services:Text Messaging Charges	
1387	suretax	180102	Cable Services:Monthly Premium Service Charges - Recurring	
1388	suretax	180105	Cable Services:Rental Charges - Remote Controls	
1389	suretax	180106	Cable Services:Rental Charges - Descrambling Devices	
1390	suretax	150101	Prepaid Wireline Services:Wireline Prepaid Service - Phone Card - Denominated In Dollars	
1391	suretax	150102	Prepaid Wireline Services:Wireline Prepaid Service - Authorization Code - Denominated In Dollars	
1392	suretax	150103	Prepaid Wireline Services:Wireline Prepaid Service - Re-Charge - Denominated In Dollars	
1393	suretax	150104	Prepaid Wireline Services:Wireline Prepaid Service - Usage	
1394	suretax	150105	Prepaid Wireline Services:Wireline Prepaid Service - Monthly Service Charge (Recurring)	
1395	suretax	150106	Prepaid Wireline Services:Wireline Prepaid Service - Initial Set Up Charge	
1396	suretax	210108	Computer Services:Sale of Canned Software - Separately Stated - Sold In Conjunction with TPP	
1397	suretax	150107	Prepaid Wireline Services:Wireline Prepaid Service - Phone Card - Denominated In Minutes	
1398	suretax	210109	Computer Services:Sale of Custom Software - Separately Stated - Sold In Conjunction with TPP	
1399	suretax	150108	Prepaid Wireline Services:Wireline Prepaid Service - Authorization Code - Denominated In Minutes	
1400	suretax	150109	Prepaid Wireline Services:Wireline Prepaid Service - Recharge  - Denominated In Minutes	
1401	suretax	310206	Digital Goods:Digital Books - Download	
1402	suretax	150201	Prepaid Wireline Services:Wireline Prepaid (Wholesale) - Sale Of Phone Card - Intrastate/Interstate	
1403	suretax	150202	Prepaid Wireline Services:Wireline Prepaid (Wholesale) - Sale Of Phone Card - Amount Attributable To Intrastate - Intralata Usage	
1404	suretax	150203	Prepaid Wireline Services:Wireline Prepaid (Wholesale) - Sale Of Phone Card - Amount Attributable To Intrastate - Interlata Usage	
1405	suretax	150204	Prepaid Wireline Services:Wireline Prepaid (Wholesale) - Sale Of Phone Card - Amount Attributable To Interstate Usage	
1406	suretax	210402	Computer Services:Canned Software - Mandatory Software Maintenance Contract-Upgrades via Load and Leave	
1407	suretax	150205	Prepaid Wireline Services:Wireline Prepaid (Wholesale) - Sale Of Phone Card - Amount Attributable To International Usage	
1408	suretax	150301	Prepaid Wireline Services:Wireline Prepaid (Retail) - Sale Of Phone Card - Intrastate/Interstate	
1409	suretax	150302	Prepaid Wireline Services:Wireline Prepaid (Retail) - Sale Of Phone Card - Amount Attributable To Intrastate - Intralata Usage	
1410	suretax	150303	Prepaid Wireline Services:Wireline Prepaid (Retail) - Sale Of Phone Card - Amount Attributable To Intrastate - Interlata Usage	
1411	suretax	210408	Computer Services:Custom Software - Mandatory Software Maintenance Contract-Upgrades via Load and Leave	
1412	suretax	150304	Prepaid Wireline Services:Wireline Prepaid (Retail) - Sale Of Phone Card - Amount Attributable To Interstate Usage	
1413	suretax	980512	Leasing:Deferred Payment Contract - Greater Than 6 Months - Stream	
1414	suretax	150305	Prepaid Wireline Services:Wireline Prepaid (Retail) - Sale Of Phone Card - Amount Attributable To International Usage	
1415	suretax	160101	Information Services:Information Service - On-Line Information Services - Separately Stated	
1416	suretax	210603	Computer Services:Custom Applications - Via Load and Leave	
1417	suretax	160102	Information Services:Information Service - On-Line Information Services -Bundled with Equipment	
1418	suretax	160103	Information Services:Information Service - Audio-Text Information Services	
1419	suretax	180107	Cable Services:Additional Premium Cable Outlets	
1420	suretax	180108	Cable Services:Installation Charges	
1421	suretax	180109	Cable Services:Broadcast Advertising Revenue	
1422	suretax	210101	Computer Services:Web Hosting	
1423	suretax	210102	Computer Services:Web Page Design	
1424	suretax	210103	Computer Services:Web Page Design Done By Third Party - Placed on the Web by the Customer	
1425	suretax	210104	Computer Services:Software Setup Fees - Separately Stated	
1426	suretax	210105	Computer Services:Canned Software Setup Sold Alone Without TPP	
1427	suretax	210106	Computer Services:Custom Software Setup Sold Along - Without TPP	
1428	suretax	210107	Computer Services:ISP Fees (Usage)	
1429	suretax	210111	Computer Services:Customization of Canned Software	
1430	suretax	210112	Computer Services:Licensing of Canned Software	
1431	suretax	210113	Computer Services:Licensing of Custom Software	
1432	suretax	210115	Computer Services:Sale of Custom Software Via Download	
1433	suretax	310101	Digital Goods:Data Processing	
1434	suretax	210117	Computer Services:Licensing of Custom Software Via Internet Download	
1435	suretax	210118	Computer Services:Computer Hardware	
1436	suretax	210119	Computer Services:Load and Leave Prewritten Software	
1437	suretax	210121	Computer Services:Canned Software License Delivered Electronically - Original Sale TPP	
1438	suretax	210122	Computer Services:Colocation	
1439	suretax	210201	Computer Services:Consulting Services Mandatory or in connection with Sale of TPP	
1440	suretax	210202	Computer Services:Consulting Services not Sold In Connection with the Sale of TPP	
1441	suretax	210301	Computer Services:On-site or Phone Support - Mandatory or in Connection with Sale of TPP	
1442	suretax	210302	Computer Services:On-site or Phone Support - Optional or Separate from Sale of TPP	
1443	suretax	210303	Computer Services:Repair or Maintenance - Hardware and Canned/Tangible (RETIRED)	
1444	suretax	210401	Computer Services:Canned Software - Mandatory Software Maintenance Contract-Upgrades via TPP	
1445	suretax	210403	Computer Services:Canned Software - Mandatory Software Maintenance Contract-Upgrades Provided Electronically	
1446	suretax	910105	Late Fees:Late Payment Fee - Utility Service - Separately Stated Fee	
1447	suretax	210404	Computer Services:Canned Software - Optional Software Maintenance Contract-Upgrades via TPP	
1448	suretax	210405	Computer Services:Canned Software - Optional Software Maintenance Contract-Upgrades via Load and Leave	
1449	suretax	210406	Computer Services:Canned Software - Optional Software Maintenance Contract-Upgrades provided Electronically	
1450	suretax	210407	Computer Services:Custom Software - Mandatory Software Maintenance Contract-Upgrades via TPP	
1451	suretax	990101	General Sales:	
1452	suretax	210409	Computer Services:Custom Software - Mandatory Software Maintenance Contract-Upgrades Electronic	
1453	suretax	210410	Computer Services:Custom Software - Optional Software Maintenance Contract-Upgrades via TPP	
1454	suretax	210411	Computer Services:Custom Software - Optional Software Maintenance Contract-Upgrades via Load and Leave	
1455	suretax	210412	Computer Services:Custom Software - Optional Software Maintenance Contract-Upgrades Electronic	
1456	suretax	350101	EDI:Data Transmission - Separately Stated	
1457	suretax	210413	Computer Services:Hardware - Mandatory Computer Maintenance Contract - with Sale of TPP	
1458	suretax	210414	Computer Services:Hardware - Optional Computer Maintenance Contract - with Sale of TPP	
1459	suretax	210415	Computer Services:Hardware - Optional Computer Maintenance Contract - not with Sale of TPP	
1460	suretax	250101	Satellite Radio Service:Service Charges	
1461	suretax	260101	Satellite TV:Monthly Basic Service Charges (Recurring)	
1462	suretax	260102	Satellite TV:Monthly Premium Service Charges (Recurring)	
1463	suretax	260103	Satellite TV:Pay-Per-View Programming (Non-Recurring)	
1464	suretax	260104	Satellite TV:Rental Charges - Receivers	
1465	suretax	260105	Satellite TV:Rental Charges - Non-Essential Equipment	
1466	suretax	260106	Satellite TV:Broadcast Advertising Revenue	
1467	suretax	260107	Satellite TV:Additional Outlets Programming Fee	
1468	suretax	260108	Satellite TV:Installation Charges	
1469	suretax	310103	Digital Goods:ASP - Server in Customer State	
1470	suretax	310104	Digital Goods:ASP - Server Not in Customer State	
1471	suretax	310105	Digital Goods:Personalized Information Service	
1472	suretax	310201	Digital Goods:Digital Audio Works and Books - Access Only	
1473	suretax	310202	Digital Goods:Digital Audio-Visual Works - Access Only	
1474	suretax	310203	Digital Goods:Digital Audio Works and Books - Download	
1475	suretax	310204	Digital Goods:Digital Audio-Visual Works - Download	
1476	suretax	330101	Alarm Monitoring:Commercial Alarm Monitoring Service	
1477	suretax	910101	Late Fees:Late Payment Fee - Standard Invoice - Separately Stated Fee	
1478	suretax	910102	Late Fees:Late Payment Fee - Standard Invoice - Fee Combined With The Base Charges	
1479	suretax	910103	Late Fees:Late Payment Fee - Lease Agreement - Separately Stated Fee	
1480	suretax	910104	Late Fees:Late Payment Fee - Lease Agreement - Fee Combined With The Base Charges	
1481	suretax	910106	Late Fees:Late Payment Fee - Utility Service - Fee Combined With The Base Charges	
1482	suretax	920102	Maintenance Contracts:Mandatory Contract Sold with Tangible Personal Property	
1483	suretax	920103	Maintenance Contracts:Optional Labor Only Contract	
1484	suretax	920104	Maintenance Contracts:Mandatory Labor-Only Contract Sold with Tangible Personal Property	
1485	suretax	930101	Repair/Maintenance:Telecom - Labor Charges (Labor Only)	
1486	suretax	930102	Repair/Maintenance:Telecom - Labor with Materials - Materials - Value Incidental - Lump Sum Bill	
1487	suretax	930103	Repair/Maintenance:Telecom - Materials - Labor with Materials - Materials- Value non-Incidental - Lump sum Bill	
1488	suretax	930104	Repair/Maintenance:Telecom - Materials - Labor With Materials - Materials- Value Non-Incidental - Materials Separately Stated	
1489	suretax	980509	Leasing:Deferred Payment Contract - 93 Days to 6 Months - Inception	
1490	suretax	930105	Repair/Maintenance:Telecom - Labor - Labor With Materials - Materials- Value Non-Incidental - Labor Separately Stated	
1491	suretax	930106	Repair/Maintenance:Telecom - Materials - Labor With Materials - Materials- Value Incidental - Materials Separately Stated	
1492	suretax	930107	Repair/Maintenance:Telecom - Labor - Labor With Materials - Materials- Value Incidental - Labor Separately Stated	
1493	suretax	970101	Shipping/Delivery:Intrastate - F.O.B. Origin - Charge Sep. Stated - Shipping & Handling - Charge Is Mandatory	
1494	suretax	970102	Shipping/Delivery:Intrastate - F.O.B. Origin - Charge Sep. Stated - Shipping & Handling - Charge Is Optional	
1495	suretax	970103	Shipping/Delivery:Intrastate - F.O.B. Origin - Charge Sep. Stated - Shipping Actual Cost Only- Charge Is Mandatory	
1496	suretax	030258	Cellular Services:Cellular Service - Airtime - Foreign Customer - Intrastate - Call Orig or Term in State	
1497	suretax	970104	Shipping/Delivery:Intrastate - F.O.B. Origin - Charge Sep. Stated - Shipping Actual Cost Only- Charge Is Optional	
1498	suretax	970105	Shipping/Delivery:Intrastate - F.O.B. Origin-Charge Sep. Stated-Shipping Actual Cost-Charge Is Opt.& Vendor Acts As Agent Is Proven	
1499	suretax	970106	Shipping/Delivery:Intrastate - F.O.B. Origin - Charge Sep. Stated - Shipping Vendor Markup Added - Charge Is Mandatory	
1500	suretax	360102	Dark Fiber:Lease of Dark Fiber to an End-User	
1501	suretax	970107	Shipping/Delivery:Intrastate - F.O.B. Origin - Charge Sep. Stated - Shipping Vendor Markup Added - Charge Is Optional	
1502	suretax	970108	Shipping/Delivery:Intrastate - F.O.B. Destination - Charge Sep. Stated - Shipping & Handling - Charge Is Mandatory	
1503	suretax	970109	Shipping/Delivery:Intrastate - F.O.B. Destination - Charge Sep. Stated - Shipping Actual Cost Only- Charge Is Mandatory	
1504	suretax	970110	Shipping/Delivery:Intrastate - F.O.B. Destination - Charge Sep. Stated - Shipping Vendor Markup Added - Charge Is Mandatory	
1505	suretax	970111	Shipping/Delivery:Intrastate - F.O.B. Dest./Purchasers Option-Charge Sep. Stated-Shipping & Handling - Charge Is Optional	
1506	suretax	970112	Shipping/Delivery:Intrastate - F.O.B. Dest./Purchasers Option-Charge Sep. Stated-Shipping Actual Cost Only-Charge Is Optional	
1507	suretax	980412	Leasing:Lease Contract - Greater Than 6 Months - Stream	
1508	suretax	970113	Shipping/Delivery:Intrastate - F.O.B. Dest./Purchasers Option-Charge Sep. Stated-Shipping Vendor Markup Added-Charge Is Optional	
1509	suretax	970114	Shipping/Delivery:Intrastate - F.O.B. Purchasers Option - Charge Sep. Stated - Shipping & Handling - Charge Is Mandatory	
1510	suretax	970115	Shipping/Delivery:Intrastate - F.O.B. Purchasers Option - Charge Sep. Stated - Shipping Actual Cost Only- Charge Is Mandatory	
1622	suretax	310208	Digital Goods:Digitial Audio-Visual Works - Less Than Permanent Right of Use	
1511	suretax	970116	Shipping/Delivery:Intrastate - F.O.B. Purchasers Option - Charge Sep. Stated - Shipping Vendor Markup Added - Charge Is Mandatory	
1512	suretax	970201	Shipping/Delivery:Interstate - F.O.B. Origin - Charge Sep. Stated - Shipping & Handling - Charge Is Mandatory	
1513	suretax	970202	Shipping/Delivery:Interstate - F.O.B. Origin - Charge Sep. Stated - Shipping & Handling - Charge Is Optional	
1514	suretax	970203	Shipping/Delivery:Interstate - F.O.B. Origin - Charge Sep. Stated - Shipping Actual Cost Only- Charge Is Mandatory	
1515	suretax	970204	Shipping/Delivery:Interstate - F.O.B. Origin - Charge Sep. Stated - Shipping Actual Cost Only- Charge Is Optional	
1516	suretax	970205	Shipping/Delivery:Interstate - F.O.B. Origin-Charge Sep. Stated-Shipping Actual Cost-Charge Is Opt.& Vendor Acts As Agent Is Proven	
1517	suretax	310207	Digital Goods:Digitial Audio Works - Less Than Permanent Right of Use	
1518	suretax	970206	Shipping/Delivery:Interstate - F.O.B. Origin - Charge Sep. Stated - Shipping Vendor Markup Added - Charge Is Mandatory	
1519	suretax	970207	Shipping/Delivery:Interstate - F.O.B. Origin - Charge Sep. Stated - Shipping Vendor Markup Added - Charge Is Optional	
1520	suretax	970208	Shipping/Delivery:Interstate - F.O.B. Destination - Charge Sep. Stated - Shipping & Handling - Charge Is Mandatory	
1521	suretax	970209	Shipping/Delivery:Interstate - F.O.B. Destination - Charge Sep. Stated - Shipping Actual Cost Only- Charge Is Mandatory	
1522	suretax	970210	Shipping/Delivery:Interstate - F.O.B. Destination - Charge Sep. Stated - Shipping Vendor Markup Added - Charge Is Mandatory	
1523	suretax	970211	Shipping/Delivery:Interstate - F.O.B. Dest./Purchasers Option-Charge Sep. Stated-Shipping & Handling - Charge Is Optional	
1524	suretax	970212	Shipping/Delivery:Interstate - F.O.B. Dest./Purchasers Option-Charge Sep. Stated-Shipping Actual Cost Only-Charge Is Optional	
1525	suretax	970213	Shipping/Delivery:Interstate - F.O.B. Dest./Purchasers Option-Charge Sep. Stated-Shipping Vendor Markup Added-Charge Is Optional	
1526	suretax	970214	Shipping/Delivery:Interstate - F.O.B. Purchasers Option - Charge Sep. Stated - Shipping & Handling - Charge Is Mandatory	
1527	suretax	070151	Private Line:Data - Connection/Disconnection - Intrastate Intracity	
1528	suretax	970215	Shipping/Delivery:Interstate - F.O.B. Purchasers Option - Charge Sep. Stated - Shipping Actual Cost Only- Charge Is Mandatory	
1529	suretax	030262	Cellular Services:Cellular Service - Long-Distance Charge - Intrastate - Call Orig or Term in State of PPU	
1530	suretax	970216	Shipping/Delivery:Interstate - F.O.B. Purchasers Option - Charge Sep. Stated - Shipping Vendor Markup Added - Charge Is Mandatory	
1531	suretax	980401	Leasing:Lease Contract - Less than 30 Days - Inception	
1532	suretax	980402	Leasing:Lease Contract - Less than 30 Days - Stream	
1533	suretax	980405	Leasing:Lease Contract - 31 to 60 Days - Inception	
1534	suretax	980406	Leasing:Lease Contract - 31 to 60 Days - Stream	
1535	suretax	980407	Leasing:Lease Contract - 61 to 92 Days - Inception	
1536	suretax	980408	Leasing:Lease Contract - 61 to 92 Days - Stream	
1537	suretax	980409	Leasing:Lease Contract - 93 Days to 6 Months - Inception	
1538	suretax	980410	Leasing:Lease Contract - 93 Days to 6 Months - Stream	
1539	suretax	980411	Leasing:Lease Contract - Greater Than 6 Months - Inception	
1540	suretax	980413	Leasing:Lease Contract - Short Term Lease Less than 30 Days	
1541	suretax	980501	Leasing:Deferred Payment Contract - Less than 30 Days - Inception	
1542	suretax	400106	Utilities:Electric - Scheduling Fee	
1543	suretax	980502	Leasing:Deferred Payment Contract - Less than 30 Days - Stream	
1544	suretax	980503	Leasing:Deferred Payment Contract - 30 Days - Inception	
1545	suretax	980504	Leasing:Deferred Payment Contract - 30 Days - Stream	
1546	suretax	980505	Leasing:Deferred Payment Contract - 31 to 60 Days - Inception	
1547	suretax	980506	Leasing:Deferred Payment Contract - 31 to 60 Days - Stream	
1548	suretax	980507	Leasing:Deferred Payment Contract - 61 to 92 Days - Inception	
1549	suretax	980508	Leasing:Deferred Payment Contract - 61 to 92 Days - Stream	
1550	suretax	980510	Leasing:Deferred Payment Contract - 93 Days to 6 Months - Stream	
1551	suretax	980511	Leasing:Deferred Payment Contract - Greater Than 6 Months - Inception	
1552	suretax	010207	Long Distance:800 Number Service - Connection/Disconnection Charges - Intrastate	
1553	suretax	010208	Long Distance:800 Number Service - Connection/Disconnection Charges - Interstate	
1554	suretax	030252	Cellular Services:Cellular Service - Airtime - Intrastate - Call Orig or Term in City of PPU	
1555	suretax	030253	Cellular Services:Cellular Service - Airtime - Intrastate - Call Orig or Term in State of PPU	
1556	suretax	030254	Cellular Services:Cellular Service - Airtime - Intrastate - Call Orig or Term in State other than PPU State	
1557	suretax	030255	Cellular Services:Cellular Service - Airtime - Interstate - Call Orig or Term in City of PPU	
1558	suretax	030256	Cellular Services:Cellular Service - Airtime - Interstate - Call Orig or Term in State of PPU	
1559	suretax	030257	Cellular Services:Cellular Service - Airtime - Interstate - Call Orig or Term in State other than PPU State	
1560	suretax	030259	Cellular Services:Cellular Service - Airtime - Foreign Customer - Interstate/International	
1561	suretax	030260	Cellular Services:Cellular Service - Long-Distance Charge - Undetermined	
1562	suretax	030261	Cellular Services:Cellular Service - Long-Distance Charge - Intrastate - Call Orig or Term in City of PPU	
1563	suretax	030263	Cellular Services:Cellular Service - Long-Distance Charge - Intrastate - Call Orig or Term in State other than PPU State	
1564	suretax	210123	Computer Services:Canned Software for Enterprise Service or Business Use - Tangible Medium	
1565	suretax	030264	Cellular Services:Cellular Service - Long-Distance Charge - Interstate - Call Orig or Term in City of PPU	
1566	suretax	030265	Cellular Services:Cellular Service - Long-Distance Charge - Interstate - Call Orig or Term in State of PPU	
1567	suretax	030266	Cellular Services:Cellular Service - Long-Distance Charge - Interstate - Call Orig or Term in State other than PPU State	
1623	suretax	310209	Digital Goods:Digital Books - Less Than Permanent Right of Use	
1568	suretax	030267	Cellular Services:Cellular Service - Long-Distance Charge - Foreign Customer - Intrastate - Call Orig or Term in State	
1569	suretax	030268	Cellular Services:Cellular Service - Long-Distance Charge - Foreign Customer - Interstate	
1570	suretax	010153	Long Distance:Toll - INTERSTATE (Originates in the state and billed to a service address in the state)	
1571	suretax	940101	Installation (non-telecom):Installation Services - Installation Service performed by Vendor-Charge Separately Stated on Invoice	
1572	suretax	940102	Installation (non-telecom):Installation Services - Installation Service performed by Vendor-Charge  Contracted Separately from Sale of TPP	
1573	suretax	940103	Installation (non-telecom):Installation Services - Installation Service performed by 3rd Party as a Separate Service	
1574	suretax	940104	Installation (non-telecom):Installation Services - Installation Vendor Sales and Install of New TPP to Real Property	
1575	suretax	940105	Installation (non-telecom):Installation Services - Installation Customer Contracted Install of New TPP to Real Property	
1576	suretax	400107	Utilities:Electric - Highpeak Demand Charge	
1577	suretax	930202	Repair/Maintenance:TPP - Lump-sum Bill for Labor and Materials, Value of Materials is Significant	
1578	suretax	930203	Repair/Maintenance:TPP - Lump-sum Bill for Labor and Materials, Value of Materials is Not Significant	
1579	suretax	930204	Repair/Maintenance:TPP - Labor Charge Separately Stated - Inv includes Charge for Materials	
1580	suretax	930205	Repair/Maintenance:TPP - Material Charge Separately Stated - Vales of Materials is Not Significant	
1581	suretax	950101	Training:Instruction - Mandatory or in Connection with Sale of TPP	
1582	suretax	950102	Training:Instruction - Optional or Separate From Sale of TPP	
1583	suretax	950103	Training:Instruction Material - Documents Delivered by TPP	
1584	suretax	950104	Training:Instruction Material - Documents Delivered by Electronically	
1585	suretax	950105	Training:Job Related Instruction - Mandatory or In Connection with Sale of TPP	
1586	suretax	950106	Training:Job Related Instruction - Optional or Separate from Sale of TPP	
1587	suretax	940201	Installation (non-telecom):Computer Hardware Installation Service - Mandatory with Sale of TPP	
1588	suretax	940202	Installation (non-telecom):Computer Hardware Installation Service - Optional with Sale of TPP	
1589	suretax	940203	Installation (non-telecom):Computer Hardware Installation Service - Mandatory with Lease of TPP	
1590	suretax	940204	Installation (non-telecom):Computer Hardware Installation Service - Optional with Lease of TPP	
1591	suretax	940205	Installation (non-telecom):Computer Hardware Installation Service - Not with Sale of TPP	
1592	suretax	210502	Computer Services:Customize Canned Apps - Above Threshold, In Connection with Sale and Analysis Of Cust. Requirements, Via Tangible Storage Media	
1593	suretax	210165	Computer Services:Colocation - Space (Cages, Racks, Cabinets, Ladders)	
1594	suretax	210503	Computer Services:Customize Canned Apps - Above Threshold, In Connection with Sale and Analysis Of Cust. Requirements, Via Electronic Delivery	
1595	suretax	210504	Computer Services:Customize Canned Apps - Above Threshold, In Connection with Sale and Analysis Of Cust. Requirements, Via Load & Leave	
1596	suretax	050301	VoIP Services:Non-interconnected VoIP - Monthly Plan - Undetermined	
1597	suretax	210124	Computer Services:Canned Software for Enterprise Service or Business Use - Electronic Medium	
1598	suretax	210125	Computer Services:Canned Software for Enterprise Service or Business Use - Load and Leave	
1599	suretax	210505	Computer Services:Customize Canned Apps - Below Threshold, In Connection with Sale and Analysis Of Cust. Requirements, Via Tangible Storage Media	
1600	suretax	210506	Computer Services:Customize Canned Apps - Below Threshold, In Connection with Sale and Analysis Of Cust. Requirements, Via Electronic Delivery	
1601	suretax	210507	Computer Services:Customize Canned Apps - Below Threshold, In Connection with Sale and Analysis Of Cust. Requirements, Via Load & Leave	
1602	suretax	210508	Computer Services:Customize Canned Apps - Performed By Third Party with Analysis Of Customer Requirements, Via Tangible Storage Media	
1603	suretax	210509	Computer Services:Customize Canned Apps - Performed By Third Party with Analysis Of Customer Requirements, Via Electronic Delivery	
1604	suretax	210510	Computer Services:Customize Canned Apps - Performed By Third Party with Analysis Of Customer Requirements, Via Load & Leave	
1605	suretax	210601	Computer Services:Custom Applications - Via Tangible Storage Media	
1606	suretax	210602	Computer Services:Custom Applications - Via Electronic Delivery	
1607	suretax	210604	Computer Services:Custom Applications - Delivered or Hosted Remotely via SaaS	
1608	suretax	210701	Computer Services:Installation of Canned Software, Mandatory In Connection With Sale Via Tangible Storage Media	
1609	suretax	210702	Computer Services:Installation of Canned Software, Optional In Connection With Sale Via Tangible Storage Media	
1610	suretax	400201	Utilities:Natural Gas - Default Equipment Charge	
1611	suretax	210703	Computer Services:Installation of Canned Software In Connection With Sale Delivered Electronically	
1612	suretax	210704	Computer Services:Installation of Canned Software, Mandatory In Connection With Sale Delivered Via Load And Leave	
1613	suretax	210705	Computer Services:Installation of Canned Software, Optional In Connection With Sale Delivered Via Load And Leave	
1614	suretax	210706	Computer Services:Installation of Canned Software Performed By Third Party Via Tangible Storage Media	
1615	suretax	210707	Computer Services:Installation of Canned Software Performed By Third Party Delivered Electronically	
1616	suretax	210708	Computer Services:Installation of Canned Software Performed By Third Party Delivered Via Load And Leave	
1617	suretax	210801	Computer Services:Installation of Custom Application Software In Connection With Sale	
1618	suretax	210802	Computer Services:Installation of Custom Application Software Performed By Third Party	
1619	suretax	210803	Computer Services:Installation of Custom O/S Software In Connection With Sale	
1620	suretax	210804	Computer Services:Installation of Custom O/S Software Performed By Third Party	
1621	suretax	310107	Digital Goods:SaaS - Canned Software not Downloadable or Sold in Other Formats (Retired)	
1624	suretax	080253	Data Lines:PSTN Data Line Non-Private - Usage Charges - Intrastate	
1625	suretax	080254	Data Lines:PSTN Data Line Non-Private - Usage Charges - Interstate	
1626	suretax	210151	Computer Services:Software and Services - CAD	
1627	suretax	210161	Computer Services:Colocation - Power	
1628	suretax	210162	Computer Services:Colocation - Power Installation	
1629	suretax	210163	Computer Services:Colocation - Maintenance	
1630	suretax	210166	Computer Services:Colocation - Space Custom (Cages, Racks, Cabinets, Ladders)	
1631	suretax	210167	Computer Services:Colocation - Space (Roof Space and Conduits)	
1632	suretax	210262	Computer Services:Consulting Services - Application Management - not sold with TPP	
1633	suretax	070150	Private Line:Data - Local Loop Connecting To Intrastate Intracity Line	
1634	suretax	050302	VoIP Services:Non-interconnected VoIP - Monthly Plan - Intrastate	
1635	suretax	050303	VoIP Services:Non-interconnected VoIP - Monthly Plan - Interstate	
1636	suretax	010151	Long Distance:Toll - Intrastate	
1637	suretax	050156	VoIP Services:Usage-Based Charges - Fixed VOIP Service - Local	
1638	suretax	050157	VoIP Services:Usage-Based Charges - Fixed VOIP Service - Intrastate	
1639	suretax	070271	Private Line:Data - Line Charge - Interstate (100% allocation, no FUSF)	
1640	suretax	070272	Private Line:Data - Channel Termination Point (Local Loop) - Interstate (100% allocation, no FUSF)	
1641	suretax	070273	Private Line:Data - Connection/Disconnection - Interstate  (100% allocation, no FUSF)	
1642	suretax	070274	Private Line:Data - Service Charge - Non-Recurring - Interstate  (100% allocation, no FUSF)	
1643	suretax	060103	Internet:Broadband Transmission - Common Carrier Basis	
1644	suretax	400101	Utilities:Electric - Default Equipment Charge	
1645	suretax	400102	Utilities:Electric - Actual Energy	
1646	suretax	400103	Utilities:Electric - Transportation/Distribution Charges	
1647	suretax	400104	Utilities:Electric - Basic Service Charge	
1648	suretax	400105	Utilities:Electric - Basic Service Charge - Usage Included	
1649	suretax	400203	Utilities:Natural Gas - Transportation/Distribution Charges	
1650	suretax	400204	Utilities:Natural Gas - Tariffed Rates for Baseline Rate Usage	
1651	suretax	400205	Utilities:Natural Gas - Basic Service Charge	
1652	suretax	400206	Utilities:Natural Gas - Basic Service Charge - Usage Included	
1653	suretax	400301	Utilities:Solar Energy - Solar Panel Lease	
1654	suretax	400302	Utilities:Solar Energy - Monthly Charge - Actual Energy	
1655	suretax	400401	Utilities:Competitive Transition Charges	
1656	suretax	400403	Utilities:Public Purpose Programs	
1657	suretax	400404	Utilities:Nuclear Decommissioning Fee	
1658	suretax	110508	Misc Telecom Charges:Conference Bridging - Stand-Alone - Undetermined - Bridge Inside State	
1659	suretax	110509	Misc Telecom Charges:Conference Bridging - Stand-Alone - Undetermined - Bridge Outside State	
1660	suretax	080154	Data Lines:Non-PSTN Data Line Non-Private - Usage Charge - Interstate	
1661	suretax	210304	Computer Services:Repair or Maintenance - Canned Software Provided via TPP	
1662	suretax	210305	Computer Services:Repair or Maintenance - Canned Software Provided via Electronic Delivery	
1663	suretax	210306	Computer Services:Repair or Maintenance - Canned Software Provided via Load and Leave	
1664	suretax	210307	Computer Services:Repair or Maintenance - Custom Applications Software Provided via TPP	
1665	suretax	210308	Computer Services:Repair or Maintenance - Custom Applications Software Provided Electronically or via Load and Leave	
1666	suretax	210309	Computer Services:Repair or Maintenance - Custom Operating System Software Provided via TPP	
1667	suretax	210310	Computer Services:Repair or Maintenance - Custom Operating System Software Provided Electronically or via Load and Leave	
1668	suretax	920105	Maintenance Contracts:Optional Labor - Only Maintenance Contract for Business	
1669	suretax	920107	Maintenance Contracts:Extended Warranty - Does not Include Parts	
1670	suretax	920108	Maintenance Contracts:Optional Maintenance Contract Sold After the Purchase of TPP	
1671	suretax	920109	Maintenance Contracts:Optional Labor - Only Maintenance Contract Sold After Purchase of TPP	
1672	suretax	920110	Maintenance Contracts:Optional Labor - Only Maintenance Contract for Business Sold After Purchase	
1673	suretax	930206	Repair/Maintenance:TPP - Labor Only Repair For Business Equipment and Machinery	
1674	suretax	930207	Repair/Maintenance:TPP - Lump-Sum Bill For Labor and Materials with Insignificant Value for Business.	
1675	suretax	950107	Training:Programmatic Grading Charge - Separately Stated	
1676	suretax	950108	Training:Grading Charge - Not Computer Based - Separately Stated	
1677	suretax	210416	Computer Services:Canned Software/ Mandatory Maintenance For Business/ Enterprise - Upgrades Via TPP	
1678	suretax	210417	Computer Services:Canned Software/ Mandatory Maintenance For Business/ Enterprise - Upgrades Via Load-And-Leave	
1679	suretax	210418	Computer Services:Canned Software/ Mandatory Maintenance For Business/ Enterprise - Upgrades Provided Electronically	
1680	suretax	210419	Computer Services:Canned Software/ Optional Maintenance For Business/ Enterprise - Upgrades Via TPP	
1681	suretax	210420	Computer Services:Canned Software/ Optional Maintenance For Business/ Enterprise - Upgrades Via Load-And-Leave	
1682	suretax	210421	Computer Services:Canned Software/ Optional Maintenance For Business/ Enterprise - Upgrades Provided Electronically	
1683	suretax	010110	Long Distance:WATS - International - Terminates and is Billed to Service Address in Same State	
1684	suretax	010111	Long Distance:WATS - International - Originates and is Billed to Service Address in Same State	
1685	suretax	010152	Long Distance:Toll - INTERSTATE (Terminate in the state and billed to a service address in the state)	
1686	suretax	400502	Utilities:Electric - Misc - Reconnection Fee	
1687	suretax	400503	Utilities:Electric - Misc - Disconnection Fee	
1688	suretax	400504	Utilities:Electric - Misc - Late Payment Fee	
1689	suretax	400505	Utilities:Electric - Misc - Returned Check Charge	
1690	suretax	400601	Utilities:Natural Gas - Misc - Connection Fee	
1691	suretax	400602	Utilities:Natural Gas - Misc - Reconnection Fee	
1692	suretax	400603	Utilities:Natural Gas - Misc - Disconnection Fee	
1693	suretax	400604	Utilities:Natural Gas - Misc - Late Payment Fee	
1694	suretax	400605	Utilities:Natural Gas - Misc - Returned Check Charge	
1695	suretax	050259	VoIP Services:Usage-Based Charges - Nomadic VOIP Service - Interstate / International (call terminates in state)	
1696	suretax	050218	VoIP Services:Nomadic VoIP - Vertical Features - Amount Attributable to Intrastate Revenues	
1697	suretax	050118	VoIP Services:Fixed VoIP - Vertical Features - Amount Attributable to Intrastate Revenues	
1698	suretax	010156	Long Distance:Long Distance Toll - International O/B	
1699	suretax	010307	Long Distance:900 Service - Interstate - Transmission & Information Service	
1700	suretax	010308	Long Distance:900 Service - Interstate - Amount Attributable To Transmission	
1701	suretax	010309	Long Distance:900 Service - Interstate - Amount Attributable To Information Service	
\.


--
-- PostgreSQL database dump complete
--

