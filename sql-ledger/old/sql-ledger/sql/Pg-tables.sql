CREATE SEQUENCE id
  start 10000;
--
SELECT nextval ('id');
--
CREATE TABLE makemodel (
  parts_id int,
  name text
);
--
CREATE TABLE gl (
  id int DEFAULT nextval ( 'id' ),
  reference text,
  description text,
  transdate date DEFAULT current_date,
  employee_id int,
  notes text
);
--
CREATE TABLE chart (
  id int DEFAULT nextval ( 'id' ),
  accno text NOT NULL,
  description text,
  charttype char(1) DEFAULT 'A',
  category char(1),
  link text,
  gifi_accno text
);
--
CREATE TABLE gifi (
  accno text,
  description text
);
--
CREATE TABLE defaults (
  inventory_accno_id int,
  income_accno_id int,
  expense_accno_id int,
  fxgain_accno_id int,
  fxloss_accno_id int,
  invnumber text,
  sonumber text,
  yearend varchar(5),
  weightunit varchar(5),
  businessnumber text,
  version varchar(8),
  curr text,
  closedto date,
  revtrans bool DEFAULT 'f',
  ponumber text
);
INSERT INTO defaults (version) VALUES ('2.0.8');
--
CREATE TABLE acc_trans (
  trans_id int,
  chart_id int,
  amount float,
  transdate date DEFAULT current_date,
  source text,
  cleared bool DEFAULT 'f',
  fx_transaction bool DEFAULT 'f',
  project_id int
);
--
CREATE TABLE invoice (
  id int DEFAULT nextval ( 'id' ),
  trans_id int,
  parts_id int,
  description text,
  qty float4,
  allocated float4,
  sellprice float,
  fxsellprice float,
  discount float4,
  assemblyitem bool DEFAULT 'f',
  unit varchar(5),
  project_id int,
  deliverydate date
);
--
CREATE TABLE vendor (
  id int DEFAULT nextval ( 'id' ),
  name varchar(35),
  addr1 varchar(35),
  addr2 varchar(35),
  addr3 varchar(35),
  addr4 varchar(35),
  contact varchar(35),
  phone varchar(20),
  fax varchar(20),
  email text,
  notes text,
  terms int2 DEFAULT 0,
  taxincluded bool,
  vendornumber text,
  cc text,
  bcc text
);
--
CREATE TABLE customer (
  id int DEFAULT nextval ( 'id' ),
  name varchar(35),
  addr1 varchar(35),
  addr2 varchar(35),
  addr3 varchar(35),
  addr4 varchar(35),
  contact varchar(35),
  phone varchar(20),
  fax varchar(20),
  email text,
  notes text,
  discount float4,
  taxincluded bool,
  creditlimit float DEFAULT 0,
  terms int2 DEFAULT 0,
  customernumber text,
  cc text,
  bcc text
);
--
CREATE TABLE parts (
  id int DEFAULT nextval ( 'id' ),
  partnumber text,
  description text,
  unit varchar(5),
  listprice float,
  sellprice float,
  lastcost float,
  priceupdate date DEFAULT current_date,
  weight float4,
  onhand float4 DEFAULT 0,
  notes text,
  makemodel bool DEFAULT 'f',
  assembly bool DEFAULT 'f',
  alternate bool DEFAULT 'f',
  rop float4,
  inventory_accno_id int,
  income_accno_id int,
  expense_accno_id int,
  bin text,
  obsolete bool DEFAULT 'f',
  bom bool DEFAULT 'f',
  image text,
  drawing text,
  microfiche text,
  partsgroup_id int
);
--
CREATE TABLE assembly (
  id int,
  parts_id int,
  qty float,
  bom bool
);
--
CREATE TABLE ar (
  id int DEFAULT nextval ( 'id' ),
  invnumber text,
  transdate date DEFAULT current_date,
  customer_id int,
  taxincluded bool,
  amount float,
  netamount float,
  paid float,
  datepaid date,
  duedate date,
  invoice bool DEFAULT 'f',
  shippingpoint text,
  terms int2 DEFAULT 0,
  notes text,
  curr char(3),
  ordnumber text,
  employee_id int
);
--
CREATE TABLE ap (
  id int DEFAULT nextval ( 'id' ),
  invnumber text,
  transdate date DEFAULT current_date,
  vendor_id int,
  taxincluded bool DEFAULT 'f',
  amount float,
  netamount float,
  paid float,
  datepaid date,
  duedate date,
  invoice bool DEFAULT 'f',
  ordnumber text,
  curr char(3),
  notes text,
  employee_id int
);
--
CREATE TABLE partstax (
  parts_id int,
  chart_id int
);
--
CREATE TABLE tax (
  chart_id int,
  rate float,
  taxnumber text
);
--
CREATE TABLE customertax (
  customer_id int,
  chart_id int
);
--
CREATE TABLE vendortax (
  vendor_id int,
  chart_id int
);
--
CREATE TABLE oe (
  id int default nextval('id'),
  ordnumber text,
  transdate date default current_date,
  vendor_id int,
  customer_id int,
  amount float8,
  netamount float8,
  reqdate date,
  taxincluded bool,
  shippingpoint text,
  notes text,
  curr char(3),
  employee_id int,
  closed bool default 'f'
);
--
CREATE TABLE orderitems (
  trans_id int,
  parts_id int,
  description text,
  qty float4,
  sellprice float8,
  discount float4,
  unit varchar(5),
  project_id int,
  reqdate date
);
--
CREATE TABLE exchangerate (
  curr char(3),
  transdate date,
  buy float8,
  sell float8
);
--
CREATE TABLE employee (
  id int DEFAULT nextval ('id'),
  login text,
  name Varchar(35),
  addr1 varchar(35),
  addr2 varchar(35),
  addr3 varchar(35),
  addr4 varchar(35),
  workphone varchar(20),
  homephone varchar(20),
  startdate date default current_date,
  enddate date,
  notes text
);
--
create table shipto (
  trans_id int,
  shiptoname varchar(35),
  shiptoaddr1 varchar(35),
  shiptoaddr2 varchar(35),
  shiptoaddr3 varchar(35),
  shiptoaddr4 varchar(35),
  shiptocontact varchar(35),
  shiptophone varchar(20),
  shiptofax varchar(20),
  shiptoemail text
);
--
create table project (
  id int default nextval('id'),
  projectnumber text,
  description text
);
--
create table partsgroup (
  id int default nextval('id'),
  partsgroup text
);
--
