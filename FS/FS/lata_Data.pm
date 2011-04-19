package FS::lata_Data;

use HTML::TableExtract;
use FS::Record qw(qsearch qsearchs dbh);

my $dbh = dbh;
my $sth = $dbh->prepare('select count(1) from lata') or die $dbh->errstr;
$sth->execute or die $sth->errstr;
my $count = $sth->fetchrow_arrayref->[0];

unless ( $count ) {
    my $content = '';
    while(<DATA>) {
        $content .= $_;
    }

    my $te = new HTML::TableExtract();
    $te->parse($content);
    my $table = $te->first_table_found;
    my $sql = 'insert into lata (latanum, description) values ';
    my @sql;
    foreach my $row ( $table->rows ) {
        my @row = @$row;
        next unless $row[0] =~ /\d+/;
        $row[1] =~ s/'//g;
        push @sql, "( ${row[0]}, '${row[1]}')";
    }
    $sql .= join(',',@sql);

    $sth = $dbh->prepare('delete from lata');
    $sth->execute or die $sth->errstr;

    $sth = $dbh->prepare($sql);
    $sth->execute or die $sth->errstr;

    $dbh->commit;
}

__DATA__

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.icra.org/ratingsv02.html" l gen true for "http://www.localcallingguide.com/" r (cz 1 lz 1 nz 1 oz 1 vz 1) "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.localcallingguide.com/" r (n 0 s 0 v 0 l 0))' /> 
<meta name="Author" content="Ray Chow" />
<meta name="Copyright" content="Compilation and programming &copy; 1996-2005 Ray Chow" />
<meta name="description" content="Local calling guide" />
<meta name="keywords" content="local calling area, npa, nxx, rate center, rate centre, prefix, area code, nanp, north american numbering plan" />
<meta name="robots" content="index,follow" />
<link rel="stylesheet" type="text/css" media="screen" href="simple.css" />
<link rel="shortcut icon" href="favicon.ico" />
<!-- <style type="text/css" media="all">@import "sophisto.css";</style> -->
<link rel="home" href="index.php" />
<title>Local calling guide: LATA</title>
</head>
<body>
<div id="content">
<div id="main">
<h1>Local Calling Guide</h1>
<h2>LATA (Local Access Transport Area)</h2>
<p>Last updated: <strong>Sat, 09 Apr 2011 16:43:35 UTC</strong></p>
<table>
<thead>
<tr>
<th id="lata">LATA</th>
<th id="descr">Description</th>
</tr>
</thead>
<tbody>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=120">120</a></td>
<td headers="descr">MAINE</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=122">122</a></td>
<td headers="descr">NEW HAMPSHIRE</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=124">124</a></td>
<td headers="descr">VERMONT</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=126">126</a></td>
<td headers="descr">WESTERN MA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=128">128</a></td>
<td headers="descr">EASTERN MA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=130">130</a></td>
<td headers="descr">RHODE ISLAND</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=132">132</a></td>
<td headers="descr">NEW YORK METRO NY</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=133">133</a></td>
<td headers="descr">POUGHKEEPSIE NY</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=134">134</a></td>
<td headers="descr">ALBANY NY</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=136">136</a></td>
<td headers="descr">SYRACUSE NY</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=138">138</a></td>
<td headers="descr">BINGHAMTON NY</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=140">140</a></td>
<td headers="descr">BUFFALO NY</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=220">220</a></td>
<td headers="descr">ATLANTIC COASTAL NJ</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=222">222</a></td>
<td headers="descr">DELAWARE VALLEY NJ</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=224">224</a></td>
<td headers="descr">NORTH JERSEY NJ</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=226">226</a></td>
<td headers="descr">CAPITAL PA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=228">228</a></td>
<td headers="descr">PHILADELPHIA PA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=230">230</a></td>
<td headers="descr">ALTOONA PA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=232">232</a></td>
<td headers="descr">NORTHEAST PA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=234">234</a></td>
<td headers="descr">PITTSBURGH PA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=236">236</a></td>
<td headers="descr">WASHINGTON DC</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=238">238</a></td>
<td headers="descr">BALTIMORE MD</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=240">240</a></td>
<td headers="descr">HAGERSTOWN MD</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=242">242</a></td>
<td headers="descr">SALISBURY MD</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=244">244</a></td>
<td headers="descr">ROANOKE VA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=246">246</a></td>
<td headers="descr">CULPEPER VA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=248">248</a></td>
<td headers="descr">RICHMOND VA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=250">250</a></td>
<td headers="descr">LYNCHBURG VA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=252">252</a></td>
<td headers="descr">NORFOLK VA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=254">254</a></td>
<td headers="descr">CHARLESTON WV</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=256">256</a></td>
<td headers="descr">CLARKSBURG WV</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=320">320</a></td>
<td headers="descr">CLEVELAND OH</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=322">322</a></td>
<td headers="descr">YOUNGSTOWN OH</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=324">324</a></td>
<td headers="descr">COLUMBUS OH</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=325">325</a></td>
<td headers="descr">AKRON OH</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=326">326</a></td>
<td headers="descr">TOLEDO OH</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=328">328</a></td>
<td headers="descr">DAYTON OH</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=330">330</a></td>
<td headers="descr">EVANSVILLE IN</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=332">332</a></td>
<td headers="descr">SOUTH BEND IN</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=334">334</a></td>
<td headers="descr">AUBURN/HUNTINGTON IN</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=336">336</a></td>
<td headers="descr">INDIANAPOLIS IN</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=338">338</a></td>
<td headers="descr">BLOOMINGTON IN</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=340">340</a></td>
<td headers="descr">DETROIT MI</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=342">342</a></td>
<td headers="descr">UPPER PENINSULA MI</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=344">344</a></td>
<td headers="descr">SAGINAW MI</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=346">346</a></td>
<td headers="descr">LANSING MI</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=348">348</a></td>
<td headers="descr">GRAND RAPIDS MI</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=350">350</a></td>
<td headers="descr">NORTHEAST WI</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=352">352</a></td>
<td headers="descr">NORTHWEST WI</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=354">354</a></td>
<td headers="descr">SOUTHWEST WI</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=356">356</a></td>
<td headers="descr">SOUTHEAST WI</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=358">358</a></td>
<td headers="descr">CHICAGO IL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=360">360</a></td>
<td headers="descr">ROCKFORD IL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=362">362</a></td>
<td headers="descr">CAIRO IL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=364">364</a></td>
<td headers="descr">STERLING IL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=366">366</a></td>
<td headers="descr">FORREST IL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=368">368</a></td>
<td headers="descr">PEORIA IL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=370">370</a></td>
<td headers="descr">CHAMPAIGN IL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=374">374</a></td>
<td headers="descr">SPRINGFIELD IL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=376">376</a></td>
<td headers="descr">QUINCY IL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=420">420</a></td>
<td headers="descr">ASHEVILLE NC</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=422">422</a></td>
<td headers="descr">CHARLOTTE NC</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=424">424</a></td>
<td headers="descr">GREENSBORO NC</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=426">426</a></td>
<td headers="descr">RALEIGH NC</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=428">428</a></td>
<td headers="descr">WILMINGTON NC</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=430">430</a></td>
<td headers="descr">GREENVILLE SC</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=432">432</a></td>
<td headers="descr">FLORENCE SC</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=434">434</a></td>
<td headers="descr">COLUMBIA SC</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=436">436</a></td>
<td headers="descr">CHARLESTON SC</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=438">438</a></td>
<td headers="descr">ATLANTA GA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=440">440</a></td>
<td headers="descr">SAVANNAH GA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=442">442</a></td>
<td headers="descr">AUGUSTA GA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=444">444</a></td>
<td headers="descr">ALBANY GA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=446">446</a></td>
<td headers="descr">MACON GA</td>
</tr>
<tr class="rc0">
<td headers="lata">448</td>
<td headers="descr">PENSACOLA FL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=44813">44813</a></td>
<td headers="descr">PENSACOLA FL PENSACOLA EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=44814">44814</a></td>
<td headers="descr">PENSACOLA FL CRESTVIEW EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=44815">44815</a></td>
<td headers="descr">PENSACOLA FL FORT WALTON BEACH EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata">450</td>
<td headers="descr">PANAMA CITY FL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=45009">45009</a></td>
<td headers="descr">PANAMA CITY FL PANAMA CITY EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=45010">45010</a></td>
<td headers="descr">PANAMA CITY FL PORT ST JOE EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=45011">45011</a></td>
<td headers="descr">PANAMA CITY FL QUINCY EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=45012">45012</a></td>
<td headers="descr">PANAMA CITY FL MARIANNA EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata">452</td>
<td headers="descr">JACKSONVILLE FL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=45204">45204</a></td>
<td headers="descr">JACKSONVILLE FL JACKSONVILLE EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=45205">45205</a></td>
<td headers="descr">JACKSONVILLE FL LIVE OAK EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata">454</td>
<td headers="descr">GAINESVILLE FL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=45402">45402</a></td>
<td headers="descr">GAINESVILLE FL GAINESVILLE EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=45403">45403</a></td>
<td headers="descr">GAINESVILLE FL OCALA EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata">456</td>
<td headers="descr">DAYTONA BEACH FL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=45601">45601</a></td>
<td headers="descr">DAYTONA BEACH FL DAYTONA BEACH EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata">458</td>
<td headers="descr">ORLANDO FL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=45806">45806</a></td>
<td headers="descr">ORLANDO FL ORLANDO EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=45807">45807</a></td>
<td headers="descr">ORLANDO FL LAKE BUENA VISTA EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=45808">45808</a></td>
<td headers="descr">ORLANDO FL WINTER PARK EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata">460</td>
<td headers="descr">SOUTHEAST FL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=46017">46017</a></td>
<td headers="descr">SOUTHEAST FL OJUS EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=46018">46018</a></td>
<td headers="descr">SOUTHEAST FL WEST PALM BEACH EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=462">462</a></td>
<td headers="descr">LOUISVILLE KY</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=464">464</a></td>
<td headers="descr">OWENSBORO KY</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=466">466</a></td>
<td headers="descr">WINCHESTER KY</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=468">468</a></td>
<td headers="descr">MEMPHIS TN</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=470">470</a></td>
<td headers="descr">NASHVILLE TN</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=472">472</a></td>
<td headers="descr">CHATTANOOGA TN</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=474">474</a></td>
<td headers="descr">KNOXVILLE TN</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=476">476</a></td>
<td headers="descr">BIRMINGHAM AL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=477">477</a></td>
<td headers="descr">HUNTSVILLE AL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=478">478</a></td>
<td headers="descr">MONTGOMERY AL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=480">480</a></td>
<td headers="descr">MOBILE AL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=482">482</a></td>
<td headers="descr">JACKSON MS</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=484">484</a></td>
<td headers="descr">BILOXI MS</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=486">486</a></td>
<td headers="descr">SHREVEPORT LA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=488">488</a></td>
<td headers="descr">LAFAYETTE LA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=490">490</a></td>
<td headers="descr">NEW ORLEANS LA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=492">492</a></td>
<td headers="descr">BATON ROUGE LA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=520">520</a></td>
<td headers="descr">ST LOUIS MO</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=521">521</a></td>
<td headers="descr">WESTPHALIA MO</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=522">522</a></td>
<td headers="descr">SPRINGFIELD MO</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=524">524</a></td>
<td headers="descr">KANSAS CITY MO/KS</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=526">526</a></td>
<td headers="descr">FORT SMITH AR</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=528">528</a></td>
<td headers="descr">LITTLE ROCK AR</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=530">530</a></td>
<td headers="descr">PINE BLUFF AR</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=532">532</a></td>
<td headers="descr">WICHITA KS</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=534">534</a></td>
<td headers="descr">TOPEKA KS</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=536">536</a></td>
<td headers="descr">OKLAHOMA CITY OK</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=538">538</a></td>
<td headers="descr">TULSA OK</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=540">540</a></td>
<td headers="descr">EL PASO TX</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=542">542</a></td>
<td headers="descr">MIDLAND TX</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=544">544</a></td>
<td headers="descr">LUBBOCK TX</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=546">546</a></td>
<td headers="descr">AMARILLO TX</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=548">548</a></td>
<td headers="descr">WICHITA FALLS TX</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=550">550</a></td>
<td headers="descr">ABILENE TX</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=552">552</a></td>
<td headers="descr">DALLAS TX</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=554">554</a></td>
<td headers="descr">LONGVIEW TX</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=556">556</a></td>
<td headers="descr">WACO TX</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=558">558</a></td>
<td headers="descr">AUSTIN TX</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=560">560</a></td>
<td headers="descr">HOUSTON TX</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=562">562</a></td>
<td headers="descr">BEAUMONT TX</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=564">564</a></td>
<td headers="descr">CORPUS CHRISTI TX</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=566">566</a></td>
<td headers="descr">SAN ANTONIO TX</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=568">568</a></td>
<td headers="descr">BROWNSVILLE TX</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=570">570</a></td>
<td headers="descr">HEARNE TX</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=620">620</a></td>
<td headers="descr">ROCHESTER MN</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=624">624</a></td>
<td headers="descr">DULUTH MN</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=626">626</a></td>
<td headers="descr">ST CLOUD MN</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=628">628</a></td>
<td headers="descr">MINNEAPOLIS MN</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=630">630</a></td>
<td headers="descr">SIOUX CITY IA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=632">632</a></td>
<td headers="descr">DES MOINES IA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=634">634</a></td>
<td headers="descr">DAVENPORT IA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=635">635</a></td>
<td headers="descr">CEDAR RAPIDS IA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=636">636</a></td>
<td headers="descr">FARGO ND</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=638">638</a></td>
<td headers="descr">BISMARCK ND</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=640">640</a></td>
<td headers="descr">SOUTH DAKOTA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=644">644</a></td>
<td headers="descr">OMAHA NE</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=646">646</a></td>
<td headers="descr">GRAND ISLAND NE</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=648">648</a></td>
<td headers="descr">GREAT FALLS MT</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=650">650</a></td>
<td headers="descr">BILLINGS MT</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=652">652</a></td>
<td headers="descr">IDAHO</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=654">654</a></td>
<td headers="descr">WYOMING</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=656">656</a></td>
<td headers="descr">DENVER CO</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=658">658</a></td>
<td headers="descr">COLORADO SPRINGS CO</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=660">660</a></td>
<td headers="descr">UTAH</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=664">664</a></td>
<td headers="descr">NEW MEXICO</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=666">666</a></td>
<td headers="descr">PHOENIX AZ</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=668">668</a></td>
<td headers="descr">TUCSON AZ</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=670">670</a></td>
<td headers="descr">EUGENE OR</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=672">672</a></td>
<td headers="descr">PORTLAND OR</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=674">674</a></td>
<td headers="descr">SEATTLE WA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=676">676</a></td>
<td headers="descr">SPOKANE WA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=720">720</a></td>
<td headers="descr">RENO NV</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=721">721</a></td>
<td headers="descr">PAHRUMP NV</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=722">722</a></td>
<td headers="descr">SAN FRANCISCO CA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=724">724</a></td>
<td headers="descr">CHICO CA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=726">726</a></td>
<td headers="descr">SACRAMENTO CA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=728">728</a></td>
<td headers="descr">FRESNO CA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=730">730</a></td>
<td headers="descr">LOS ANGELES CA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=732">732</a></td>
<td headers="descr">SAN DIEGO CA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=734">734</a></td>
<td headers="descr">BAKERSFIELD CA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=736">736</a></td>
<td headers="descr">MONTEREY CA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=738">738</a></td>
<td headers="descr">STOCKTON CA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=740">740</a></td>
<td headers="descr">SAN LUIS OBISPO CA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=820">820</a></td>
<td headers="descr">PUERTO RICO</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=822">822</a></td>
<td headers="descr">US VIRGIN ISLANDS</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=824">824</a></td>
<td headers="descr">BAHAMAS</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=826">826</a></td>
<td headers="descr">JAMAICA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=828">828</a></td>
<td headers="descr">DOMINICAN REPUBLIC</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=830">830</a></td>
<td headers="descr">CARIBBEAN</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=832">832</a></td>
<td headers="descr">ALASKA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=834">834</a></td>
<td headers="descr">HAWAII</td>
</tr>
<tr class="rc1">
<td headers="lata">836</td>
<td headers="descr">MIDWAY/WAKE</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=870">870</a></td>
<td headers="descr">NORTHERN MARIANA ISLANDS</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=871">871</a></td>
<td headers="descr">GUAM</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=884">884</a></td>
<td headers="descr">AMERICAN SAMOA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=888">888</a></td>
<td headers="descr">CANADA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=920">920</a></td>
<td headers="descr">CONNECTICUT (SNET)</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=921">921</a></td>
<td headers="descr">FISHERS ISLAND NY</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=922">922</a></td>
<td headers="descr">CINCINNATI OH</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=923">923</a></td>
<td headers="descr">MANSFIELD OH</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=924">924</a></td>
<td headers="descr">ERIE PA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=927">927</a></td>
<td headers="descr">HARRISONBURG VA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=928">928</a></td>
<td headers="descr">CHARLOTTESVILLE VA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=929">929</a></td>
<td headers="descr">EDINBURG VA</td>
</tr>
<tr class="rc0">
<td headers="lata">930</td>
<td headers="descr">EPPES FORK VA (now part of 248) </td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=932">932</a></td>
<td headers="descr">BLUEFIELD WV</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=937">937</a></td>
<td headers="descr">RICHMOND IN</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=938">938</a></td>
<td headers="descr">TERRE HAUTE IN</td>
</tr>
<tr class="rc0">
<td headers="lata">939</td>
<td headers="descr">FORT MYERS FL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=93901">93901</a></td>
<td headers="descr">FORT MYERS FL AVON PARK EAEA</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=93902">93902</a></td>
<td headers="descr">FORT MYERS FL FORT MYERS EAEA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=949">949</a></td>
<td headers="descr">FAYETTEVILLE NC</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=951">951</a></td>
<td headers="descr">ROCKY MOUNT NC</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=952">952</a></td>
<td headers="descr">GULF COAST</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=953">953</a></td>
<td headers="descr">TALLAHASSEE FL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=956">956</a></td>
<td headers="descr">BRISTOL TN</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=958">958</a></td>
<td headers="descr">LINCOLN NE</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=960">960</a></td>
<td headers="descr">COEUR D'ALENE ID</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=961">961</a></td>
<td headers="descr">SAN ANGELO TX</td>
</tr>
<tr class="rc1">
<td headers="lata">963</td>
<td headers="descr">KALISPELL MT (now part of 648) </td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=973">973</a></td>
<td headers="descr">PALM SPRINGS CA</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=974">974</a></td>
<td headers="descr">ROCHESTER NY</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=976">976</a></td>
<td headers="descr">MATTOON IL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=977">977</a></td>
<td headers="descr">MACOMB IL</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=978">978</a></td>
<td headers="descr">OLNEY IL</td>
</tr>
<tr class="rc1">
<td headers="lata"><a href="lca_listexch.php?lata=980">980</a></td>
<td headers="descr">NAVAJO RESERVATION AZ</td>
</tr>
<tr class="rc0">
<td headers="lata"><a href="lca_listexch.php?lata=981">981</a></td>
<td headers="descr">NAVAJO RESERVATION UT</td>
</tr>
</tbody>
</table>
<p>Sponsored by <a href="http://www.voicemeup.com/">VoiceMeUp - Corporate VoIP Services</a></p>
</div>


	<div id="nav">
	<h4>about</h4>
	<ul>
	<li class="first"><a href="index.php">main</a></li>
	<li><a href="updates.php">what's new</a></li>
	<li><a href="feedback.php">feedback</a></li>
	<li><a href="saq.php">SAQ</a></li>
	</ul>
	<h4>lists</h4>
	<ul>
	<li class="first"><a href="lca_listregion.php">region</a></li>
	<li><a href="lca_listnpa.php">area code</a></li>
	<li><a href="lca_listlata.php">LATA</a></li>
	</ul>
	<h4>search</h4>
	<ul>
	<li class="first"><a href="lca_prefix.php">area code/prefix</a></li>
	<li><a href="lca_listexch.php">rate centre</a></li>
	<li><a href="lca_switch.php">switch</a></li>
	<li><a href="lca_telco.php">telco</a></li>
	<li><a href="lca_activity.php">local calling area changes</a></li>
	<li><a href="lca_cic.php">dial-around code</a></li>
	<li><a href="lca_rcdist.php">local call finder</a></li>
	</ul>
	<h4>misc</h4>
	<ul>
	<li class="first"><a href="xmlquery.php">XML query</a></li>
	<li><a href="lca_tariff.php">tariffs</a></li>
	<li><a href="lca_link.php">other links</a></li>
	<li><a href="http://groups.yahoo.com/group/local-calling-guide/">discuss</a></li>
	</ul>
	<p>Like this site? We accept donations via PayPal.</p>
<form action="https://www.paypal.com/cgi-bin/webscr" method="post">
<input type="hidden" name="cmd" value="_s-xclick">
<input type="hidden" name="hosted_button_id" value="WAD39TRXXRCXJ">
<input type="image" src="https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!">
<img alt="" border="0" src="https://www.paypal.com/en_US/i/scr/pixel.gif" width="1" height="1">
</form>
	</div>
</div>
<div id="footer">
<script src="http://www.google-analytics.com/urchin.js" type="text/javascript">
</script>
<script type="text/javascript">
_uacct = "UA-943522-1";
urchinTracker();
</script>
</div>
</body>
</html>

