package FS::msa_Data;

use FS::Record qw(qsearch qsearchs dbh);

my $dbh = dbh;
my $sth = $dbh->prepare('select count(1) from msa') or die $dbh->errstr;
$sth->execute or die $sth->errstr;
my $count = $sth->fetchrow_arrayref->[0];

unless ( $count ) {
    my $content = '';
    while(<DATA>) {
        $content .= $_;
    }
    my @content = split(/\n/,$content);

    my $sql = 'insert into msa (msanum, description) values ';
    my @sql;
    foreach my $row ( @content ) {
        next unless $row =~ /^([0-9]{5})\s+([A-Za-z,\. \-]{5,80}) .{3}ropolitan Statistical Area/;
        push @sql, "( $1, '$2')";
    }
    $sql .= join(',',@sql);

    my $sth = $dbh->prepare('delete from msa');
    $sth->execute or die $sth->errstr;

    $sth = $dbh->prepare($sql);
    $sth->execute or die $sth->errstr;

    $dbh->commit;
}

__DATA__

METROPOLITAN AND MICROPOLITAN STATISTICAL AREAS AND COMPONENTS, December 2009, WITH CODES

(Metropolitan and micropolitan statistical areas, and metropolitan divisions defined by the Office of Management and Budget, December 2009)

Source:                 U.S. Census Bureau, Population Division
Internet Release Date:  September 2010
Last Revised:           

                FIPS
CBSA   Div      State/
Code   Code     County  CBSA and Division Titles and Components
10020                   Abbeville, LA Micropolitan Statistical Area
10020           22113         Vermilion Parish, LA

10100                   Aberdeen, SD Micropolitan Statistical Area
10100           46013         Brown County, SD
10100           46045         Edmunds County, SD

10140                   Aberdeen, WA Micropolitan Statistical Area
10140           53027         Grays Harbor County, WA

10180                   Abilene, TX Metropolitan Statistical Area
10180           48059         Callahan County, TX
10180           48253         Jones County, TX
10180           48441         Taylor County, TX

10220                   Ada, OK Micropolitan Statistical Area
10220           40123         Pontotoc County, OK

10260                   Adjuntas, PR Micropolitan Statistical Area
10260           72001         Adjuntas Municipio, PR

10300                   Adrian, MI Micropolitan Statistical Area
10300           26091         Lenawee County, MI

10380                   Aguadilla-Isabela-San Sebastián, PR Metropolitan Statistical Area
10380           72003         Aguada Municipio, PR
10380           72005         Aguadilla Municipio, PR
10380           72011         Añasco Municipio, PR
10380           72071         Isabela Municipio, PR
10380           72081         Lares Municipio, PR
10380           72099         Moca Municipio, PR
10380           72117         Rincón Municipio, PR
10380           72131         San Sebastián Municipio, PR

10420                   Akron, OH Metropolitan Statistical Area
10420           39133         Portage County, OH
10420           39153         Summit County, OH

10460                   Alamogordo, NM Micropolitan Statistical Area
10460           35035         Otero County, NM

10500                   Albany, GA Metropolitan Statistical Area
10500           13007         Baker County, GA
10500           13095         Dougherty County, GA
10500           13177         Lee County, GA
10500           13273         Terrell County, GA
10500           13321         Worth County, GA

10540                   Albany-Lebanon, OR Micropolitan Statistical Area
10540           41043         Linn County, OR

10580                   Albany-Schenectady-Troy, NY Metropolitan Statistical Area
10580           36001         Albany County, NY
10580           36083         Rensselaer County, NY
10580           36091         Saratoga County, NY
10580           36093         Schenectady County, NY
10580           36095         Schoharie County, NY

10620                   Albemarle, NC Micropolitan Statistical Area
10620           37167         Stanly County, NC

10660                   Albert Lea, MN Micropolitan Statistical Area
10660           27047         Freeborn County, MN

10700                   Albertville, AL Micropolitan Statistical Area
10700           01095         Marshall County, AL

10740                   Albuquerque, NM Metropolitan Statistical Area
10740           35001         Bernalillo County, NM
10740           35043         Sandoval County, NM
10740           35057         Torrance County, NM
10740           35061         Valencia County, NM

10760                   Alexander City, AL Micropolitan Statistical Area
10760           01037         Coosa County, AL
10760           01123         Tallapoosa County, AL

10780                   Alexandria, LA Metropolitan Statistical Area
10780           22043         Grant Parish, LA
10780           22079         Rapides Parish, LA

10820                   Alexandria, MN Micropolitan Statistical Area
10820           27041         Douglas County, MN

10860                   Alice, TX Micropolitan Statistical Area
10860           48249         Jim Wells County, TX

10880                   Allegan, MI Micropolitan Statistical Area
10880           26005         Allegan County, MI

10900                   Allentown-Bethlehem-Easton, PA-NJ Metropolitan Statistical Area
10900           34041         Warren County, NJ
10900           42025         Carbon County, PA
10900           42077         Lehigh County, PA
10900           42095         Northampton County, PA

10940                   Alma, MI Micropolitan Statistical Area
10940           26057         Gratiot County, MI

10980                   Alpena, MI Micropolitan Statistical Area
10980           26007         Alpena County, MI

11020                   Altoona, PA Metropolitan Statistical Area
11020           42013         Blair County, PA

11060                   Altus, OK Micropolitan Statistical Area
11060           40065         Jackson County, OK

11100                   Amarillo, TX Metropolitan Statistical Area
11100           48011         Armstrong County, TX
11100           48065         Carson County, TX
11100           48375         Potter County, TX
11100           48381         Randall County, TX

11140                   Americus, GA Micropolitan Statistical Area
11140           13249         Schley County, GA
11140           13261         Sumter County, GA

11180                   Ames, IA Metropolitan Statistical Area
11180           19169         Story County, IA

11220                   Amsterdam, NY Micropolitan Statistical Area
11220           36057         Montgomery County, NY

11260                   Anchorage, AK Metropolitan Statistical Area
11260           02020         Anchorage Municipality, AK
11260           02170         Matanuska-Susitna Borough, AK

11300                   Anderson, IN Metropolitan Statistical Area
11300           18095         Madison County, IN

11340                   Anderson, SC Metropolitan Statistical Area
11340           45007         Anderson County, SC

11380                   Andrews, TX Micropolitan Statistical Area
11380           48003         Andrews County, TX

11420                   Angola, IN Micropolitan Statistical Area
11420           18151         Steuben County, IN

11460                   Ann Arbor, MI Metropolitan Statistical Area
11460           26161         Washtenaw County, MI

11500                   Anniston-Oxford, AL Metropolitan Statistical Area
11500           01015         Calhoun County, AL

11540                   Appleton, WI Metropolitan Statistical Area
11540           55015         Calumet County, WI
11540           55087         Outagamie County, WI

11580                   Arcadia, FL Micropolitan Statistical Area
11580           12027         DeSoto County, FL

11620                   Ardmore, OK Micropolitan Statistical Area
11620           40019         Carter County, OK
11620           40085         Love County, OK

11660                   Arkadelphia, AR Micropolitan Statistical Area
11660           05019         Clark County, AR

11700                   Asheville, NC Metropolitan Statistical Area
11700           37021         Buncombe County, NC
11700           37087         Haywood County, NC
11700           37089         Henderson County, NC
11700           37115         Madison County, NC

11740                   Ashland, OH Micropolitan Statistical Area
11740           39005         Ashland County, OH

11780                   Ashtabula, OH Micropolitan Statistical Area
11780           39007         Ashtabula County, OH

11820                   Astoria, OR Micropolitan Statistical Area
11820           41007         Clatsop County, OR

11860                   Atchison, KS Micropolitan Statistical Area
11860           20005         Atchison County, KS

11900                   Athens, OH Micropolitan Statistical Area
11900           39009         Athens County, OH

11940                   Athens, TN Micropolitan Statistical Area
11940           47107         McMinn County, TN

11980                   Athens, TX Micropolitan Statistical Area
11980           48213         Henderson County, TX

12020                   Athens-Clarke County, GA Metropolitan Statistical Area
12020           13059         Clarke County, GA
12020           13195         Madison County, GA
12020           13219         Oconee County, GA
12020           13221         Oglethorpe County, GA

12060                   Atlanta-Sandy Springs-Marietta, GA Metropolitan Statistical Area
12060           13013         Barrow County, GA
12060           13015         Bartow County, GA
12060           13035         Butts County, GA
12060           13045         Carroll County, GA
12060           13057         Cherokee County, GA
12060           13063         Clayton County, GA
12060           13067         Cobb County, GA
12060           13077         Coweta County, GA
12060           13085         Dawson County, GA
12060           13089         DeKalb County, GA
12060           13097         Douglas County, GA
12060           13113         Fayette County, GA
12060           13117         Forsyth County, GA
12060           13121         Fulton County, GA
12060           13135         Gwinnett County, GA
12060           13143         Haralson County, GA
12060           13149         Heard County, GA
12060           13151         Henry County, GA
12060           13159         Jasper County, GA
12060           13171         Lamar County, GA
12060           13199         Meriwether County, GA
12060           13217         Newton County, GA
12060           13223         Paulding County, GA
12060           13227         Pickens County, GA
12060           13231         Pike County, GA
12060           13247         Rockdale County, GA
12060           13255         Spalding County, GA
12060           13297         Walton County, GA

12100                   Atlantic City-Hammonton, NJ Metropolitan Statistical Area
12100           34001         Atlantic County, NJ

12140                   Auburn, IN Micropolitan Statistical Area
12140           18033         DeKalb County, IN

12180                   Auburn, NY Micropolitan Statistical Area
12180           36011         Cayuga County, NY

12220                   Auburn-Opelika, AL Metropolitan Statistical Area
12220           01081         Lee County, AL

12260                   Augusta-Richmond County, GA-SC Metropolitan Statistical Area
12260           13033         Burke County, GA
12260           13073         Columbia County, GA
12260           13189         McDuffie County, GA
12260           13245         Richmond County, GA
12260           45003         Aiken County, SC
12260           45037         Edgefield County, SC

12300                   Augusta-Waterville, ME Micropolitan Statistical Area
12300           23011         Kennebec County, ME

12380                   Austin, MN Micropolitan Statistical Area
12380           27099         Mower County, MN

12420                   Austin-Round Rock-San Marcos, TX Metropolitan Statistical Area
12420           48021         Bastrop County, TX
12420           48055         Caldwell County, TX
12420           48209         Hays County, TX
12420           48453         Travis County, TX
12420           48491         Williamson County, TX

12460                   Bainbridge, GA Micropolitan Statistical Area
12460           13087         Decatur County, GA

12540                   Bakersfield-Delano, CA Metropolitan Statistical Area
12540           06029         Kern County, CA

12580                   Baltimore-Towson, MD Metropolitan Statistical Area
12580           24003         Anne Arundel County, MD
12580           24005         Baltimore County, MD
12580           24013         Carroll County, MD
12580           24025         Harford County, MD
12580           24027         Howard County, MD
12580           24035         Queen Anne's County, MD
12580           24510         Baltimore city, MD

12620                   Bangor, ME Metropolitan Statistical Area
12620           23019         Penobscot County, ME

12660                   Baraboo, WI Micropolitan Statistical Area
12660           55111         Sauk County, WI

12700                   Barnstable Town, MA Metropolitan Statistical Area
12700           25001         Barnstable County, MA

12740                   Barre, VT Micropolitan Statistical Area
12740           50023         Washington County, VT

12780                   Bartlesville, OK Micropolitan Statistical Area
12780           40147         Washington County, OK

12820                   Bastrop, LA Micropolitan Statistical Area
12820           22067         Morehouse Parish, LA

12860                   Batavia, NY Micropolitan Statistical Area
12860           36037         Genesee County, NY

12900                   Batesville, AR Micropolitan Statistical Area
12900           05063         Independence County, AR

12940                   Baton Rouge, LA Metropolitan Statistical Area
12940           22005         Ascension Parish, LA
12940           22033         East Baton Rouge Parish, LA
12940           22037         East Feliciana Parish, LA
12940           22047         Iberville Parish, LA
12940           22063         Livingston Parish, LA
12940           22077         Pointe Coupee Parish, LA
12940           22091         St. Helena Parish, LA
12940           22121         West Baton Rouge Parish, LA
12940           22125         West Feliciana Parish, LA

12980                   Battle Creek, MI Metropolitan Statistical Area
12980           26025         Calhoun County, MI

13020                   Bay City, MI Metropolitan Statistical Area
13020           26017         Bay County, MI

13060                   Bay City, TX Micropolitan Statistical Area
13060           48321         Matagorda County, TX

13100                   Beatrice, NE Micropolitan Statistical Area
13100           31067         Gage County, NE

13140                   Beaumont-Port Arthur, TX Metropolitan Statistical Area
13140           48199         Hardin County, TX
13140           48245         Jefferson County, TX
13140           48361         Orange County, TX

13180                   Beaver Dam, WI Micropolitan Statistical Area
13180           55027         Dodge County, WI

13220                   Beckley, WV Micropolitan Statistical Area
13220           54081         Raleigh County, WV

13260                   Bedford, IN Micropolitan Statistical Area
13260           18093         Lawrence County, IN

13300                   Beeville, TX Micropolitan Statistical Area
13300           48025         Bee County, TX

13340                   Bellefontaine, OH Micropolitan Statistical Area
13340           39091         Logan County, OH

13380                   Bellingham, WA Metropolitan Statistical Area
13380           53073         Whatcom County, WA

13420                   Bemidji, MN Micropolitan Statistical Area
13420           27007         Beltrami County, MN

13460                   Bend, OR Metropolitan Statistical Area
13460           41017         Deschutes County, OR

13500                   Bennettsville, SC Micropolitan Statistical Area
13500           45069         Marlboro County, SC

13540                   Bennington, VT Micropolitan Statistical Area
13540           50003         Bennington County, VT

13620                   Berlin, NH-VT Micropolitan Statistical Area
13620           33007         Coos County, NH
13620           50009         Essex County, VT

13660                   Big Rapids, MI Micropolitan Statistical Area
13660           26107         Mecosta County, MI

13700                   Big Spring, TX Micropolitan Statistical Area
13700           48227         Howard County, TX

13740                   Billings, MT Metropolitan Statistical Area
13740           30009         Carbon County, MT
13740           30111         Yellowstone County, MT

13780                   Binghamton, NY Metropolitan Statistical Area
13780           36007         Broome County, NY
13780           36107         Tioga County, NY

13820                   Birmingham-Hoover, AL Metropolitan Statistical Area
13820           01007         Bibb County, AL
13820           01009         Blount County, AL
13820           01021         Chilton County, AL
13820           01073         Jefferson County, AL
13820           01115         St. Clair County, AL
13820           01117         Shelby County, AL
13820           01127         Walker County, AL

13860                   Bishop, CA Micropolitan Statistical Area
13860           06027         Inyo County, CA

13900                   Bismarck, ND Metropolitan Statistical Area
13900           38015         Burleigh County, ND
13900           38059         Morton County, ND

13940                   Blackfoot, ID Micropolitan Statistical Area
13940           16011         Bingham County, ID

13980                   Blacksburg-Christiansburg-Radford, VA Metropolitan Statistical Area
13980           51071         Giles County, VA
13980           51121         Montgomery County, VA
13980           51155         Pulaski County, VA
13980           51750         Radford city, VA

14020                   Bloomington, IN Metropolitan Statistical Area
14020           18055         Greene County, IN
14020           18105         Monroe County, IN
14020           18119         Owen County, IN

14060                   Bloomington-Normal, IL Metropolitan Statistical Area
14060           17113         McLean County, IL

14100                   Bloomsburg-Berwick, PA Micropolitan Statistical Area
14100           42037         Columbia County, PA
14100           42093         Montour County, PA

14140                   Bluefield, WV-VA Micropolitan Statistical Area
14140           51185         Tazewell County, VA
14140           54055         Mercer County, WV

14180                   Blytheville, AR Micropolitan Statistical Area
14180           05093         Mississippi County, AR

14220                   Bogalusa, LA Micropolitan Statistical Area
14220           22117         Washington Parish, LA

14260                   Boise City-Nampa, ID Metropolitan Statistical Area
14260           16001         Ada County, ID
14260           16015         Boise County, ID
14260           16027         Canyon County, ID
14260           16045         Gem County, ID
14260           16073         Owyhee County, ID

14300                   Bonham, TX Micropolitan Statistical Area
14300           48147         Fannin County, TX

14340                   Boone, IA Micropolitan Statistical Area
14340           19015         Boone County, IA

14380                   Boone, NC Micropolitan Statistical Area
14380           37189         Watauga County, NC

14420                   Borger, TX Micropolitan Statistical Area
14420           48233         Hutchinson County, TX

14460                   Boston-Cambridge-Quincy, MA-NH Metropolitan Statistical Area
14460   14484              Boston-Quincy, MA Metropolitan Division
14460   14484   25021         Norfolk County, MA
14460   14484   25023         Plymouth County, MA
14460   14484   25025         Suffolk County, MA
14460   15764              Cambridge-Newton-Framingham, MA Metropolitan Division
14460   15764   25017         Middlesex County, MA
14460   37764              Peabody, MA Metropolitan Division
14460   37764   25009         Essex County, MA
14460   40484              Rockingham County-Strafford County, NH Metropolitan Division
14460   40484   33015         Rockingham County, NH
14460   40484   33017         Strafford County, NH

14500                   Boulder, CO Metropolitan Statistical Area
14500           08013         Boulder County, CO

14540                   Bowling Green, KY Metropolitan Statistical Area
14540           21061         Edmonson County, KY
14540           21227         Warren County, KY

14580                   Bozeman, MT Micropolitan Statistical Area
14580           30031         Gallatin County, MT

14620                   Bradford, PA Micropolitan Statistical Area
14620           42083         McKean County, PA

14660                   Brainerd, MN Micropolitan Statistical Area
14660           27021         Cass County, MN
14660           27035         Crow Wing County, MN

14700                   Branson, MO Micropolitan Statistical Area
14700           29209         Stone County, MO
14700           29213         Taney County, MO

14740                   Bremerton-Silverdale, WA Metropolitan Statistical Area
14740           53035         Kitsap County, WA

14780                   Brenham, TX Micropolitan Statistical Area
14780           48477         Washington County, TX

14820                   Brevard, NC Micropolitan Statistical Area
14820           37175         Transylvania County, NC

14860                   Bridgeport-Stamford-Norwalk, CT Metropolitan Statistical Area
14860           09001         Fairfield County, CT

14940                   Brigham City, UT Micropolitan Statistical Area
14940           49003         Box Elder County, UT

15020                   Brookhaven, MS Micropolitan Statistical Area
15020           28085         Lincoln County, MS

15060                   Brookings, OR Micropolitan Statistical Area
15060           41015         Curry County, OR

15100                   Brookings, SD Micropolitan Statistical Area
15100           46011         Brookings County, SD

15140                   Brownsville, TN Micropolitan Statistical Area
15140           47075         Haywood County, TN

15180                   Brownsville-Harlingen, TX Metropolitan Statistical Area
15180           48061         Cameron County, TX

15220                   Brownwood, TX Micropolitan Statistical Area
15220           48049         Brown County, TX

15260                   Brunswick, GA Metropolitan Statistical Area
15260           13025         Brantley County, GA
15260           13127         Glynn County, GA
15260           13191         McIntosh County, GA

15340                   Bucyrus, OH Micropolitan Statistical Area
15340           39033         Crawford County, OH

15380                   Buffalo-Niagara Falls, NY Metropolitan Statistical Area
15380           36029         Erie County, NY
15380           36063         Niagara County, NY

15420                   Burley, ID Micropolitan Statistical Area
15420           16031         Cassia County, ID
15420           16067         Minidoka County, ID

15460                   Burlington, IA-IL Micropolitan Statistical Area
15460           17071         Henderson County, IL
15460           19057         Des Moines County, IA

15500                   Burlington, NC Metropolitan Statistical Area
15500           37001         Alamance County, NC

15540                   Burlington-South Burlington, VT Metropolitan Statistical Area
15540           50007         Chittenden County, VT
15540           50011         Franklin County, VT
15540           50013         Grand Isle County, VT

15580                   Butte-Silver Bow, MT Micropolitan Statistical Area
15580           30093         Silver Bow County, MT

15620                   Cadillac, MI Micropolitan Statistical Area
15620           26113         Missaukee County, MI
15620           26165         Wexford County, MI

15660                   Calhoun, GA Micropolitan Statistical Area
15660           13129         Gordon County, GA

15700                   Cambridge, MD Micropolitan Statistical Area
15700           24019         Dorchester County, MD

15740                   Cambridge, OH Micropolitan Statistical Area
15740           39059         Guernsey County, OH

15780                   Camden, AR Micropolitan Statistical Area
15780           05013         Calhoun County, AR
15780           05103         Ouachita County, AR

15820                   Campbellsville, KY Micropolitan Statistical Area
15820           21217         Taylor County, KY

15860                   Cañon City, CO Micropolitan Statistical Area
15860           08043         Fremont County, CO

15900                   Canton, IL Micropolitan Statistical Area
15900           17057         Fulton County, IL

15940                   Canton-Massillon, OH Metropolitan Statistical Area
15940           39019         Carroll County, OH
15940           39151         Stark County, OH

15980                   Cape Coral-Fort Myers, FL Metropolitan Statistical Area
15980           12071         Lee County, FL

16020                   Cape Girardeau-Jackson, MO-IL Metropolitan Statistical Area
16020           17003         Alexander County, IL
16020           29017         Bollinger County, MO
16020           29031         Cape Girardeau County, MO

16060                   Carbondale, IL Micropolitan Statistical Area
16060           17077         Jackson County, IL

16100                   Carlsbad-Artesia, NM Micropolitan Statistical Area
16100           35015         Eddy County, NM

16180                   Carson City, NV Metropolitan Statistical Area
16180           32510         Carson City, NV

16220                   Casper, WY Metropolitan Statistical Area
16220           56025         Natrona County, WY

16260                   Cedar City, UT Micropolitan Statistical Area
16260           49021         Iron County, UT

16300                   Cedar Rapids, IA Metropolitan Statistical Area
16300           19011         Benton County, IA
16300           19105         Jones County, IA
16300           19113         Linn County, IA

16340                   Cedartown, GA Micropolitan Statistical Area
16340           13233         Polk County, GA

16380                   Celina, OH Micropolitan Statistical Area
16380           39107         Mercer County, OH

16420                   Central City, KY Micropolitan Statistical Area
16420           21177         Muhlenberg County, KY

16460                   Centralia, IL Micropolitan Statistical Area
16460           17121         Marion County, IL

16500                   Centralia, WA Micropolitan Statistical Area
16500           53041         Lewis County, WA

16540                   Chambersburg, PA Micropolitan Statistical Area
16540           42055         Franklin County, PA

16580                   Champaign-Urbana, IL Metropolitan Statistical Area
16580           17019         Champaign County, IL
16580           17053         Ford County, IL
16580           17147         Piatt County, IL

16620                   Charleston, WV Metropolitan Statistical Area
16620           54005         Boone County, WV
16620           54015         Clay County, WV
16620           54039         Kanawha County, WV
16620           54043         Lincoln County, WV
16620           54079         Putnam County, WV

16660                   Charleston-Mattoon, IL Micropolitan Statistical Area
16660           17029         Coles County, IL
16660           17035         Cumberland County, IL

16700                   Charleston-North Charleston-Summerville, SC Metropolitan Statistical Area
16700           45015         Berkeley County, SC
16700           45019         Charleston County, SC
16700           45035         Dorchester County, SC

16740                   Charlotte-Gastonia-Rock Hill, NC-SC Metropolitan Statistical Area
16740           37007         Anson County, NC
16740           37025         Cabarrus County, NC
16740           37071         Gaston County, NC
16740           37119         Mecklenburg County, NC
16740           37179         Union County, NC
16740           45091         York County, SC

16820                   Charlottesville, VA Metropolitan Statistical Area
16820           51003         Albemarle County, VA
16820           51065         Fluvanna County, VA
16820           51079         Greene County, VA
16820           51125         Nelson County, VA
16820           51540         Charlottesville city, VA

16860                   Chattanooga, TN-GA Metropolitan Statistical Area
16860           13047         Catoosa County, GA
16860           13083         Dade County, GA
16860           13295         Walker County, GA
16860           47065         Hamilton County, TN
16860           47115         Marion County, TN
16860           47153         Sequatchie County, TN

16900                   Chester, SC Micropolitan Statistical Area
16900           45023         Chester County, SC

16940                   Cheyenne, WY Metropolitan Statistical Area
16940           56021         Laramie County, WY

16980                   Chicago-Joliet-Naperville, IL-IN-WI Metropolitan Statistical Area
16980   16974              Chicago-Joliet-Naperville, IL Metropolitan Division
16980   16974   17031         Cook County, IL
16980   16974   17037         DeKalb County, IL
16980   16974   17043         DuPage County, IL
16980   16974   17063         Grundy County, IL
16980   16974   17089         Kane County, IL
16980   16974   17093         Kendall County, IL
16980   16974   17111         McHenry County, IL
16980   16974   17197         Will County, IL
16980   23844              Gary, IN Metropolitan Division
16980   23844   18073         Jasper County, IN
16980   23844   18089         Lake County, IN
16980   23844   18111         Newton County, IN
16980   23844   18127         Porter County, IN
16980   29404              Lake County-Kenosha County, IL-WI Metropolitan Division
16980   29404   17097         Lake County, IL
16980   29404   55059         Kenosha County, WI

17020                   Chico, CA Metropolitan Statistical Area
17020           06007         Butte County, CA

17060                   Chillicothe, OH Micropolitan Statistical Area
17060           39141         Ross County, OH

17140                   Cincinnati-Middletown, OH-KY-IN Metropolitan Statistical Area
17140           18029         Dearborn County, IN
17140           18047         Franklin County, IN
17140           18115         Ohio County, IN
17140           21015         Boone County, KY
17140           21023         Bracken County, KY
17140           21037         Campbell County, KY
17140           21077         Gallatin County, KY
17140           21081         Grant County, KY
17140           21117         Kenton County, KY
17140           21191         Pendleton County, KY
17140           39015         Brown County, OH
17140           39017         Butler County, OH
17140           39025         Clermont County, OH
17140           39061         Hamilton County, OH
17140           39165         Warren County, OH

17200                   Claremont, NH Micropolitan Statistical Area
17200           33019         Sullivan County, NH

17220                   Clarksburg, WV Micropolitan Statistical Area
17220           54017         Doddridge County, WV
17220           54033         Harrison County, WV
17220           54091         Taylor County, WV

17260                   Clarksdale, MS Micropolitan Statistical Area
17260           28027         Coahoma County, MS

17300                   Clarksville, TN-KY Metropolitan Statistical Area
17300           21047         Christian County, KY
17300           21221         Trigg County, KY
17300           47125         Montgomery County, TN
17300           47161         Stewart County, TN

17340                   Clearlake, CA Micropolitan Statistical Area
17340           06033         Lake County, CA

17380                   Cleveland, MS Micropolitan Statistical Area
17380           28011         Bolivar County, MS

17420                   Cleveland, TN Metropolitan Statistical Area
17420           47011         Bradley County, TN
17420           47139         Polk County, TN

17460                   Cleveland-Elyria-Mentor, OH Metropolitan Statistical Area
17460           39035         Cuyahoga County, OH
17460           39055         Geauga County, OH
17460           39085         Lake County, OH
17460           39093         Lorain County, OH
17460           39103         Medina County, OH

17500                   Clewiston, FL Micropolitan Statistical Area
17500           12051         Hendry County, FL

17540                   Clinton, IA Micropolitan Statistical Area
17540           19045         Clinton County, IA

17580                   Clovis, NM Micropolitan Statistical Area
17580           35009         Curry County, NM

17620                   Coamo, PR Micropolitan Statistical Area
17620           72043         Coamo Municipio, PR
17620           72123         Salinas Municipio, PR

17660                   Coeur d'Alene, ID Metropolitan Statistical Area
17660           16055         Kootenai County, ID

17700                   Coffeyville, KS Micropolitan Statistical Area
17700           20125         Montgomery County, KS

17740                   Coldwater, MI Micropolitan Statistical Area
17740           26023         Branch County, MI

17780                   College Station-Bryan, TX Metropolitan Statistical Area
17780           48041         Brazos County, TX
17780           48051         Burleson County, TX
17780           48395         Robertson County, TX

17820                   Colorado Springs, CO Metropolitan Statistical Area
17820           08041         El Paso County, CO
17820           08119         Teller County, CO

17860                   Columbia, MO Metropolitan Statistical Area
17860           29019         Boone County, MO
17860           29089         Howard County, MO

17900                   Columbia, SC Metropolitan Statistical Area
17900           45017         Calhoun County, SC
17900           45039         Fairfield County, SC
17900           45055         Kershaw County, SC
17900           45063         Lexington County, SC
17900           45079         Richland County, SC
17900           45081         Saluda County, SC

17940                   Columbia, TN Micropolitan Statistical Area
17940           47119         Maury County, TN

17980                   Columbus, GA-AL Metropolitan Statistical Area
17980           01113         Russell County, AL
17980           13053         Chattahoochee County, GA
17980           13145         Harris County, GA
17980           13197         Marion County, GA
17980           13215         Muscogee County, GA

18020                   Columbus, IN Metropolitan Statistical Area
18020           18005         Bartholomew County, IN

18060                   Columbus, MS Micropolitan Statistical Area
18060           28087         Lowndes County, MS

18100                   Columbus, NE Micropolitan Statistical Area
18100           31141         Platte County, NE

18140                   Columbus, OH Metropolitan Statistical Area
18140           39041         Delaware County, OH
18140           39045         Fairfield County, OH
18140           39049         Franklin County, OH
18140           39089         Licking County, OH
18140           39097         Madison County, OH
18140           39117         Morrow County, OH
18140           39129         Pickaway County, OH
18140           39159         Union County, OH

18180                   Concord, NH Micropolitan Statistical Area
18180           33013         Merrimack County, NH

18220                   Connersville, IN Micropolitan Statistical Area
18220           18041         Fayette County, IN

18260                   Cookeville, TN Micropolitan Statistical Area
18260           47087         Jackson County, TN
18260           47133         Overton County, TN
18260           47141         Putnam County, TN

18300                   Coos Bay, OR Micropolitan Statistical Area
18300           41011         Coos County, OR

18340                   Corbin, KY Micropolitan Statistical Area
18340           21235         Whitley County, KY

18380                   Cordele, GA Micropolitan Statistical Area
18380           13081         Crisp County, GA

18420                   Corinth, MS Micropolitan Statistical Area
18420           28003         Alcorn County, MS

18460                   Cornelia, GA Micropolitan Statistical Area
18460           13137         Habersham County, GA

18500                   Corning, NY Micropolitan Statistical Area
18500           36101         Steuben County, NY

18580                   Corpus Christi, TX Metropolitan Statistical Area
18580           48007         Aransas County, TX
18580           48355         Nueces County, TX
18580           48409         San Patricio County, TX

18620                   Corsicana, TX Micropolitan Statistical Area
18620           48349         Navarro County, TX

18660                   Cortland, NY Micropolitan Statistical Area
18660           36023         Cortland County, NY

18700                   Corvallis, OR Metropolitan Statistical Area
18700           41003         Benton County, OR

18740                   Coshocton, OH Micropolitan Statistical Area
18740           39031         Coshocton County, OH

18820                   Crawfordsville, IN Micropolitan Statistical Area
18820           18107         Montgomery County, IN

18860                   Crescent City, CA Micropolitan Statistical Area
18860           06015         Del Norte County, CA

18880                   Crestview-Fort Walton Beach-Destin, FL Metropolitan Statistical Area
18880           12091         Okaloosa County, FL

18900                   Crossville, TN Micropolitan Statistical Area
18900           47035         Cumberland County, TN

18940                   Crowley, LA Micropolitan Statistical Area
18940           22001         Acadia Parish, LA

18980                   Cullman, AL Micropolitan Statistical Area
18980           01043         Cullman County, AL

19020                   Culpeper, VA Micropolitan Statistical Area
19020           51047         Culpeper County, VA

19060                   Cumberland, MD-WV Metropolitan Statistical Area
19060           24001         Allegany County, MD
19060           54057         Mineral County, WV

19100                   Dallas-Fort Worth-Arlington, TX Metropolitan Statistical Area
19100   19124              Dallas-Plano-Irving, TX Metropolitan Division
19100   19124   48085         Collin County, TX
19100   19124   48113         Dallas County, TX
19100   19124   48119         Delta County, TX
19100   19124   48121         Denton County, TX
19100   19124   48139         Ellis County, TX
19100   19124   48231         Hunt County, TX
19100   19124   48257         Kaufman County, TX
19100   19124   48397         Rockwall County, TX
19100   23104              Fort Worth-Arlington, TX Metropolitan Division
19100   23104   48251         Johnson County, TX
19100   23104   48367         Parker County, TX
19100   23104   48439         Tarrant County, TX
19100   23104   48497         Wise County, TX

19140                   Dalton, GA Metropolitan Statistical Area
19140           13213         Murray County, GA
19140           13313         Whitfield County, GA

19180                   Danville, IL Metropolitan Statistical Area
19180           17183         Vermilion County, IL

19220                   Danville, KY Micropolitan Statistical Area
19220           21021         Boyle County, KY
19220           21137         Lincoln County, KY

19260                   Danville, VA Metropolitan Statistical Area
19260           51143         Pittsylvania County, VA
19260           51590         Danville city, VA

19300                   Daphne-Fairhope-Foley, AL Micropolitan Statistical Area
19300           01003         Baldwin County, AL

19340                   Davenport-Moline-Rock Island, IA-IL Metropolitan Statistical Area
19340           17073         Henry County, IL
19340           17131         Mercer County, IL
19340           17161         Rock Island County, IL
19340           19163         Scott County, IA

19380                   Dayton, OH Metropolitan Statistical Area
19380           39057         Greene County, OH
19380           39109         Miami County, OH
19380           39113         Montgomery County, OH
19380           39135         Preble County, OH

19460                   Decatur, AL Metropolitan Statistical Area
19460           01079         Lawrence County, AL
19460           01103         Morgan County, AL

19500                   Decatur, IL Metropolitan Statistical Area
19500           17115         Macon County, IL

19540                   Decatur, IN Micropolitan Statistical Area
19540           18001         Adams County, IN

19580                   Defiance, OH Micropolitan Statistical Area
19580           39039         Defiance County, OH

19620                   Del Rio, TX Micropolitan Statistical Area
19620           48465         Val Verde County, TX

19660                   Deltona-Daytona Beach-Ormond Beach, FL Metropolitan Statistical Area
19660           12127         Volusia County, FL

19700                   Deming, NM Micropolitan Statistical Area
19700           35029         Luna County, NM

19740                   Denver-Aurora-Broomfield, CO Metropolitan Statistical Area
19740           08001         Adams County, CO
19740           08005         Arapahoe County, CO
19740           08014         Broomfield County, CO
19740           08019         Clear Creek County, CO
19740           08031         Denver County, CO
19740           08035         Douglas County, CO
19740           08039         Elbert County, CO
19740           08047         Gilpin County, CO
19740           08059         Jefferson County, CO
19740           08093         Park County, CO

19760                   DeRidder, LA Micropolitan Statistical Area
19760           22011         Beauregard Parish, LA

19780                   Des Moines-West Des Moines, IA Metropolitan Statistical Area
19780           19049         Dallas County, IA
19780           19077         Guthrie County, IA
19780           19121         Madison County, IA
19780           19153         Polk County, IA
19780           19181         Warren County, IA

19820                   Detroit-Warren-Livonia, MI Metropolitan Statistical Area
19820   19804              Detroit-Livonia-Dearborn, MI Metropolitan Division
19820   19804   26163         Wayne County, MI 
19820   47644              Warren-Troy-Farmington Hills, MI Metropolitan Division
19820   47644   26087         Lapeer County, MI
19820   47644   26093         Livingston County, MI
19820   47644   26099         Macomb County, MI
19820   47644   26125         Oakland County, MI
19820   47644   26147         St. Clair County, MI

19860                   Dickinson, ND Micropolitan Statistical Area
19860           38007         Billings County, ND
19860           38089         Stark County, ND

19900                   Dillon, SC Micropolitan Statistical Area
19900           45033         Dillon County, SC

19940                   Dixon, IL Micropolitan Statistical Area
19940           17103         Lee County, IL

19980                   Dodge City, KS Micropolitan Statistical Area
19980           20057         Ford County, KS

20020                   Dothan, AL Metropolitan Statistical Area
20020           01061         Geneva County, AL
20020           01067         Henry County, AL
20020           01069         Houston County, AL

20060                   Douglas, GA Micropolitan Statistical Area
20060           13003         Atkinson County, GA
20060           13069         Coffee County, GA

20100                   Dover, DE Metropolitan Statistical Area
20100           10001         Kent County, DE

20140                   Dublin, GA Micropolitan Statistical Area
20140           13167         Johnson County, GA
20140           13175         Laurens County, GA

20180                   DuBois, PA Micropolitan Statistical Area
20180           42033         Clearfield County, PA

20220                   Dubuque, IA Metropolitan Statistical Area
20220           19061         Dubuque County, IA

20260                   Duluth, MN-WI Metropolitan Statistical Area
20260           27017         Carlton County, MN
20260           27137         St. Louis County, MN
20260           55031         Douglas County, WI

20300                   Dumas, TX Micropolitan Statistical Area
20300           48341         Moore County, TX

20340                   Duncan, OK Micropolitan Statistical Area
20340           40137         Stephens County, OK

20380                   Dunn, NC Micropolitan Statistical Area
20380           37085         Harnett County, NC

20420                   Durango, CO Micropolitan Statistical Area
20420           08067         La Plata County, CO

20460                   Durant, OK Micropolitan Statistical Area
20460           40013         Bryan County, OK

20500                   Durham-Chapel Hill, NC Metropolitan Statistical Area
20500           37037         Chatham County, NC
20500           37063         Durham County, NC
20500           37135         Orange County, NC
20500           37145         Person County, NC

20540                   Dyersburg, TN Micropolitan Statistical Area
20540           47045         Dyer County, TN

20580                   Eagle Pass, TX Micropolitan Statistical Area
20580           48323         Maverick County, TX

20620                   East Liverpool-Salem, OH Micropolitan Statistical Area
20620           39029         Columbiana County, OH

20660                   Easton, MD Micropolitan Statistical Area
20660           24041         Talbot County, MD

20700                   East Stroudsburg, PA Micropolitan Statistical Area
20700           42089         Monroe County, PA

20740                   Eau Claire, WI Metropolitan Statistical Area
20740           55017         Chippewa County, WI
20740           55035         Eau Claire County, WI

20780                   Edwards, CO Micropolitan Statistical Area
20780           08037         Eagle County, CO
20780           08065         Lake County, CO

20820                   Effingham, IL Micropolitan Statistical Area
20820           17049         Effingham County, IL

20900                   El Campo, TX Micropolitan Statistical Area
20900           48481         Wharton County, TX

20940                   El Centro, CA Metropolitan Statistical Area
20940           06025         Imperial County, CA

20980                   El Dorado, AR Micropolitan Statistical Area
20980           05139         Union County, AR

21020                   Elizabeth City, NC Micropolitan Statistical Area
21020           37029         Camden County, NC
21020           37139         Pasquotank County, NC
21020           37143         Perquimans County, NC

21060                   Elizabethtown, KY Metropolitan Statistical Area
21060           21093         Hardin County, KY
21060           21123         Larue County, KY

21120                   Elk City, OK Micropolitan Statistical Area
21120           40009         Beckham County, OK

21140                   Elkhart-Goshen, IN Metropolitan Statistical Area
21140           18039         Elkhart County, IN

21220                   Elko, NV Micropolitan Statistical Area
21220           32007         Elko County, NV
21220           32011         Eureka County, NV

21260                   Ellensburg, WA Micropolitan Statistical Area
21260           53037         Kittitas County, WA

21300                   Elmira, NY Metropolitan Statistical Area
21300           36015         Chemung County, NY

21340                   El Paso, TX Metropolitan Statistical Area
21340           48141         El Paso County, TX

21380                   Emporia, KS Micropolitan Statistical Area
21380           20017         Chase County, KS
21380           20111         Lyon County, KS

21420                   Enid, OK Micropolitan Statistical Area
21420           40047         Garfield County, OK

21460                   Enterprise-Ozark, AL Micropolitan Statistical Area
21460           01031         Coffee County, AL
21460           01045         Dale County, AL

21500                   Erie, PA Metropolitan Statistical Area
21500           42049         Erie County, PA

21540                   Escanaba, MI Micropolitan Statistical Area
21540           26041         Delta County, MI

21580                   Espanola, NM Micropolitan Statistical Area
21580           35039         Rio Arriba County, NM

21640                   Eufaula, AL-GA Micropolitan Statistical Area
21640           01005         Barbour County, AL
21640           13239         Quitman County, GA

21660                   Eugene-Springfield, OR Metropolitan Statistical Area
21660           41039         Lane County, OR

21700                   Eureka-Arcata-Fortuna, CA Micropolitan Statistical Area
21700           06023         Humboldt County, CA

21740                   Evanston, WY Micropolitan Statistical Area
21740           56041         Uinta County, WY

21780                   Evansville, IN-KY Metropolitan Statistical Area
21780           18051         Gibson County, IN
21780           18129         Posey County, IN
21780           18163         Vanderburgh County, IN
21780           18173         Warrick County, IN
21780           21101         Henderson County, KY
21780           21233         Webster County, KY

21820                   Fairbanks, AK Metropolitan Statistical Area
21820           02090         Fairbanks North Star Borough, AK

21860                   Fairmont, MN Micropolitan Statistical Area
21860           27091         Martin County, MN

21900                   Fairmont, WV Micropolitan Statistical Area
21900           54049         Marion County, WV

21940                   Fajardo, PR Metropolitan Statistical Area
21940           72037         Ceiba Municipio, PR
21940           72053         Fajardo Municipio, PR
21940           72089         Luquillo Municipio, PR

21980                   Fallon, NV Micropolitan Statistical Area
21980           32001         Churchill County, NV

22020                   Fargo, ND-MN Metropolitan Statistical Area
22020           27027         Clay County, MN
22020           38017         Cass County, ND

22060                   Faribault-Northfield, MN Micropolitan Statistical Area
22060           27131         Rice County, MN

22100                   Farmington, MO Micropolitan Statistical Area
22100           29187         St. Francois County, MO

22140                   Farmington, NM Metropolitan Statistical Area
22140           35045         San Juan County, NM

22180                   Fayetteville, NC Metropolitan Statistical Area
22180           37051         Cumberland County, NC
22180           37093         Hoke County, NC

22220                   Fayetteville-Springdale-Rogers, AR-MO Metropolitan Statistical Area
22220           05007         Benton County, AR
22220           05087         Madison County, AR
22220           05143         Washington County, AR
22220           29119         McDonald County, MO

22260                   Fergus Falls, MN Micropolitan Statistical Area
22260           27111         Otter Tail County, MN

22280                   Fernley, NV Micropolitan Statistical Area
22280           32019         Lyon County, NV

22300                   Findlay, OH Micropolitan Statistical Area
22300           39063         Hancock County, OH

22340                   Fitzgerald, GA Micropolitan Statistical Area
22340           13017         Ben Hill County, GA
22340           13155         Irwin County, GA

22380                   Flagstaff, AZ Metropolitan Statistical Area
22380           04005         Coconino County, AZ

22420                   Flint, MI Metropolitan Statistical Area
22420           26049         Genesee County, MI

22500                   Florence, SC Metropolitan Statistical Area
22500           45031         Darlington County, SC
22500           45041         Florence County, SC

22520                   Florence-Muscle Shoals, AL Metropolitan Statistical Area
22520           01033         Colbert County, AL
22520           01077         Lauderdale County, AL

22540                   Fond du Lac, WI Metropolitan Statistical Area
22540           55039         Fond du Lac County, WI

22580                   Forest City, NC Micropolitan Statistical Area
22580           37161         Rutherford County, NC

22620                   Forrest City, AR Micropolitan Statistical Area
22620           05123         St. Francis County, AR

22660                   Fort Collins-Loveland, CO Metropolitan Statistical Area
22660           08069         Larimer County, CO

22700                   Fort Dodge, IA Micropolitan Statistical Area
22700           19187         Webster County, IA

22780                   Fort Leonard Wood, MO Micropolitan Statistical Area
22780           29169         Pulaski County, MO

22800                   Fort Madison-Keokuk, IA-MO Micropolitan Statistical Area
22800           19111         Lee County, IA
22800           29045         Clark County, MO

22820                   Fort Morgan, CO Micropolitan Statistical Area
22820           08087         Morgan County, CO

22840                   Fort Payne, AL Micropolitan Statistical Area
22840           01049         DeKalb County, AL

22860                   Fort Polk South, LA Micropolitan Statistical Area
22860           22115         Vernon Parish, LA

22900                   Fort Smith, AR-OK Metropolitan Statistical Area
22900           05033         Crawford County, AR
22900           05047         Franklin County, AR
22900           05131         Sebastian County, AR
22900           40079         Le Flore County, OK
22900           40135         Sequoyah County, OK

22980                   Fort Valley, GA Micropolitan Statistical Area
22980           13225         Peach County, GA

23060                   Fort Wayne, IN Metropolitan Statistical Area
23060           18003         Allen County, IN
23060           18179         Wells County, IN
23060           18183         Whitley County, IN

23140                   Frankfort, IN Micropolitan Statistical Area
23140           18023         Clinton County, IN

23180                   Frankfort, KY Micropolitan Statistical Area
23180           21005         Anderson County, KY
23180           21073         Franklin County, KY

23240                   Fredericksburg, TX Micropolitan Statistical Area
23240           48171         Gillespie County, TX

23300                   Freeport, IL Micropolitan Statistical Area
23300           17177         Stephenson County, IL

23340                   Fremont, NE Micropolitan Statistical Area
23340           31053         Dodge County, NE

23380                   Fremont, OH Micropolitan Statistical Area
23380           39143         Sandusky County, OH

23420                   Fresno, CA Metropolitan Statistical Area
23420           06019         Fresno County, CA

23460                   Gadsden, AL Metropolitan Statistical Area
23460           01055         Etowah County, AL

23500                   Gaffney, SC Micropolitan Statistical Area
23500           45021         Cherokee County, SC

23540                   Gainesville, FL Metropolitan Statistical Area
23540           12001         Alachua County, FL
23540           12041         Gilchrist County, FL

23580                   Gainesville, GA Metropolitan Statistical Area
23580           13139         Hall County, GA

23620                   Gainesville, TX Micropolitan Statistical Area
23620           48097         Cooke County, TX

23660                   Galesburg, IL Micropolitan Statistical Area
23660           17095         Knox County, IL
23660           17187         Warren County, IL

23700                   Gallup, NM Micropolitan Statistical Area
23700           35031         McKinley County, NM

23780                   Garden City, KS Micropolitan Statistical Area
23780           20055         Finney County, KS

23820                   Gardnerville Ranchos, NV Micropolitan Statistical Area
23820           32005         Douglas County, NV

23860                   Georgetown, SC Micropolitan Statistical Area
23860           45043         Georgetown County, SC

23900                   Gettysburg, PA Micropolitan Statistical Area
23900           42001         Adams County, PA

23940                   Gillette, WY Micropolitan Statistical Area
23940           56005         Campbell County, WY

23980                   Glasgow, KY Micropolitan Statistical Area
23980           21009         Barren County, KY
23980           21169         Metcalfe County, KY

24020                   Glens Falls, NY Metropolitan Statistical Area
24020           36113         Warren County, NY
24020           36115         Washington County, NY

24100                   Gloversville, NY Micropolitan Statistical Area
24100           36035         Fulton County, NY

24140                   Goldsboro, NC Metropolitan Statistical Area
24140           37191         Wayne County, NC

24180                   Granbury, TX Micropolitan Statistical Area
24180           48221         Hood County, TX
24180           48425         Somervell County, TX

24220                   Grand Forks, ND-MN Metropolitan Statistical Area
24220           27119         Polk County, MN
24220           38035         Grand Forks County, ND

24260                   Grand Island, NE Micropolitan Statistical Area
24260           31079         Hall County, NE
24260           31093         Howard County, NE
24260           31121         Merrick County, NE

24300                   Grand Junction, CO Metropolitan Statistical Area
24300           08077         Mesa County, CO

24340                   Grand Rapids-Wyoming, MI Metropolitan Statistical Area
24340           26015         Barry County, MI
24340           26067         Ionia County, MI
24340           26081         Kent County, MI
24340           26123         Newaygo County, MI

24380                   Grants, NM Micropolitan Statistical Area
24380           35006         Cibola County, NM

24420                   Grants Pass, OR Micropolitan Statistical Area
24420           41033         Josephine County, OR

24460                   Great Bend, KS Micropolitan Statistical Area
24460           20009         Barton County, KS

24500                   Great Falls, MT Metropolitan Statistical Area
24500           30013         Cascade County, MT

24540                   Greeley, CO Metropolitan Statistical Area
24540           08123         Weld County, CO

24580                   Green Bay, WI Metropolitan Statistical Area
24580           55009         Brown County, WI
24580           55061         Kewaunee County, WI
24580           55083         Oconto County, WI

24620                   Greeneville, TN Micropolitan Statistical Area
24620           47059         Greene County, TN

24660                   Greensboro-High Point, NC Metropolitan Statistical Area
24660           37081         Guilford County, NC
24660           37151         Randolph County, NC
24660           37157         Rockingham County, NC

24700                   Greensburg, IN Micropolitan Statistical Area
24700           18031         Decatur County, IN

24740                   Greenville, MS Micropolitan Statistical Area
24740           28151         Washington County, MS

24780                   Greenville, NC Metropolitan Statistical Area
24780           37079         Greene County, NC
24780           37147         Pitt County, NC

24820                   Greenville, OH Micropolitan Statistical Area
24820           39037         Darke County, OH

24860                   Greenville-Mauldin-Easley, SC Metropolitan Statistical Area
24860           45045         Greenville County, SC
24860           45059         Laurens County, SC
24860           45077         Pickens County, SC

24900                   Greenwood, MS Micropolitan Statistical Area
24900           28015         Carroll County, MS
24900           28083         Leflore County, MS

24940                   Greenwood, SC Micropolitan Statistical Area
24940           45047         Greenwood County, SC

24980                   Grenada, MS Micropolitan Statistical Area
24980           28043         Grenada County, MS

25020                   Guayama, PR Metropolitan Statistical Area
25020           72015         Arroyo Municipio, PR
25020           72057         Guayama Municipio, PR
25020           72109         Patillas Municipio, PR

25060                   Gulfport-Biloxi, MS Metropolitan Statistical Area
25060           28045         Hancock County, MS
25060           28047         Harrison County, MS
25060           28131         Stone County, MS

25100                   Guymon, OK Micropolitan Statistical Area
25100           40139         Texas County, OK

25180                   Hagerstown-Martinsburg, MD-WV Metropolitan Statistical Area
25180           24043         Washington County, MD
25180           54003         Berkeley County, WV
25180           54065         Morgan County, WV

25220                   Hammond, LA Micropolitan Statistical Area
25220           22105         Tangipahoa Parish, LA

25260                   Hanford-Corcoran, CA Metropolitan Statistical Area
25260           06031         Kings County, CA

25300                   Hannibal, MO Micropolitan Statistical Area
25300           29127         Marion County, MO
25300           29173         Ralls County, MO

25340                   Harriman, TN Micropolitan Statistical Area
25340           47145         Roane County, TN

25380                   Harrisburg, IL Micropolitan Statistical Area
25380           17165         Saline County, IL

25420                   Harrisburg-Carlisle, PA Metropolitan Statistical Area
25420           42041         Cumberland County, PA
25420           42043         Dauphin County, PA
25420           42099         Perry County, PA

25460                   Harrison, AR Micropolitan Statistical Area
25460           05009         Boone County, AR
25460           05101         Newton County, AR

25500                   Harrisonburg, VA Metropolitan Statistical Area
25500           51165         Rockingham County, VA
25500           51660         Harrisonburg city, VA

25540                   Hartford-West Hartford-East Hartford, CT Metropolitan Statistical Area
25540           09003         Hartford County, CT
25540           09007         Middlesex County, CT
25540           09013         Tolland County, CT

25580                   Hastings, NE Micropolitan Statistical Area
25580           31001         Adams County, NE
25580           31035         Clay County, NE

25620                   Hattiesburg, MS Metropolitan Statistical Area
25620           28035         Forrest County, MS
25620           28073         Lamar County, MS
25620           28111         Perry County, MS

25660                   Havre, MT Micropolitan Statistical Area
25660           30041         Hill County, MT

25700                   Hays, KS Micropolitan Statistical Area
25700           20051         Ellis County, KS

25720                   Heber, UT Micropolitan Statistical Area
25720           49051         Wasatch County, UT

25740                   Helena, MT Micropolitan Statistical Area
25740           30043         Jefferson County, MT
25740           30049         Lewis and Clark County, MT

25760                   Helena-West Helena, AR Micropolitan Statistical Area
25760           05107         Phillips County, AR

25780                   Henderson, NC Micropolitan Statistical Area
25780           37181         Vance County, NC

25820                   Hereford, TX Micropolitan Statistical Area
25820           48117         Deaf Smith County, TX

25860                   Hickory-Lenoir-Morganton, NC Metropolitan Statistical Area
25860           37003         Alexander County, NC
25860           37023         Burke County, NC
25860           37027         Caldwell County, NC
25860           37035         Catawba County, NC

25900                   Hilo, HI Micropolitan Statistical Area
25900           15001         Hawaii County, HI

25940                   Hilton Head Island-Beaufort, SC Micropolitan Statistical Area
25940           45013         Beaufort County, SC
25940           45053         Jasper County, SC

25980                   Hinesville-Fort Stewart, GA Metropolitan Statistical Area
25980           13179         Liberty County, GA
25980           13183         Long County, GA

26020                   Hobbs, NM Micropolitan Statistical Area
26020           35025         Lea County, NM

26100                   Holland-Grand Haven, MI Metropolitan Statistical Area
26100           26139         Ottawa County, MI

26140                   Homosassa Springs, FL Micropolitan Statistical Area
26140           12017         Citrus County, FL

26180                   Honolulu, HI Metropolitan Statistical Area
26180           15003         Honolulu County, HI

26220                   Hood River, OR Micropolitan Statistical Area
26220           41027         Hood River County, OR

26260                   Hope, AR Micropolitan Statistical Area
26260           05057         Hempstead County, AR
26260           05099         Nevada County, AR

26300                   Hot Springs, AR Metropolitan Statistical Area
26300           05051         Garland County, AR

26340                   Houghton, MI Micropolitan Statistical Area
26340           26061         Houghton County, MI
26340           26083         Keweenaw County, MI

26380                   Houma-Bayou Cane-Thibodaux, LA Metropolitan Statistical Area
26380           22057         Lafourche Parish, LA
26380           22109         Terrebonne Parish, LA

26420                   Houston-Sugar Land-Baytown, TX Metropolitan Statistical Area
26420           48015         Austin County, TX
26420           48039         Brazoria County, TX
26420           48071         Chambers County, TX
26420           48157         Fort Bend County, TX
26420           48167         Galveston County, TX
26420           48201         Harris County, TX
26420           48291         Liberty County, TX
26420           48339         Montgomery County, TX
26420           48407         San Jacinto County, TX
26420           48473         Waller County, TX

26460                   Hudson, NY Micropolitan Statistical Area
26460           36021         Columbia County, NY

26480                   Humboldt, TN Micropolitan Statistical Area
26480           47053         Gibson County, TN

26500                   Huntingdon, PA Micropolitan Statistical Area
26500           42061         Huntingdon County, PA

26540                   Huntington, IN Micropolitan Statistical Area
26540           18069         Huntington County, IN

26580                   Huntington-Ashland, WV-KY-OH Metropolitan Statistical Area
26580           21019         Boyd County, KY
26580           21089         Greenup County, KY
26580           39087         Lawrence County, OH
26580           54011         Cabell County, WV
26580           54099         Wayne County, WV

26620                   Huntsville, AL Metropolitan Statistical Area
26620           01083         Limestone County, AL
26620           01089         Madison County, AL

26660                   Huntsville, TX Micropolitan Statistical Area
26660           48471         Walker County, TX

26700                   Huron, SD Micropolitan Statistical Area
26700           46005         Beadle County, SD

26740                   Hutchinson, KS Micropolitan Statistical Area
26740           20155         Reno County, KS

26780                   Hutchinson, MN Micropolitan Statistical Area
26780           27085         McLeod County, MN

26820                   Idaho Falls, ID Metropolitan Statistical Area
26820           16019         Bonneville County, ID
26820           16051         Jefferson County, ID

26860                   Indiana, PA Micropolitan Statistical Area
26860           42063         Indiana County, PA

26900                   Indianapolis-Carmel, IN Metropolitan Statistical Area
26900           18011         Boone County, IN
26900           18013         Brown County, IN
26900           18057         Hamilton County, IN
26900           18059         Hancock County, IN
26900           18063         Hendricks County, IN
26900           18081         Johnson County, IN
26900           18097         Marion County, IN
26900           18109         Morgan County, IN
26900           18133         Putnam County, IN
26900           18145         Shelby County, IN

26940                   Indianola, MS Micropolitan Statistical Area
26940           28133         Sunflower County, MS

26980                   Iowa City, IA Metropolitan Statistical Area
26980           19103         Johnson County, IA
26980           19183         Washington County, IA

27020                   Iron Mountain, MI-WI Micropolitan Statistical Area
27020           26043         Dickinson County, MI
27020           55037         Florence County, WI

27060                   Ithaca, NY Metropolitan Statistical Area
27060           36109         Tompkins County, NY

27100                   Jackson, MI Metropolitan Statistical Area
27100           26075         Jackson County, MI

27140                   Jackson, MS Metropolitan Statistical Area
27140           28029         Copiah County, MS
27140           28049         Hinds County, MS
27140           28089         Madison County, MS
27140           28121         Rankin County, MS
27140           28127         Simpson County, MS

27180                   Jackson, TN Metropolitan Statistical Area
27180           47023         Chester County, TN
27180           47113         Madison County, TN

27220                   Jackson, WY-ID Micropolitan Statistical Area
27220           16081         Teton County, ID
27220           56039         Teton County, WY

27260                   Jacksonville, FL Metropolitan Statistical Area
27260           12003         Baker County, FL
27260           12019         Clay County, FL
27260           12031         Duval County, FL
27260           12089         Nassau County, FL
27260           12109         St. Johns County, FL

27300                   Jacksonville, IL Micropolitan Statistical Area
27300           17137         Morgan County, IL
27300           17171         Scott County, IL

27340                   Jacksonville, NC Metropolitan Statistical Area
27340           37133         Onslow County, NC

27380                   Jacksonville, TX Micropolitan Statistical Area
27380           48073         Cherokee County, TX

27420                   Jamestown, ND Micropolitan Statistical Area
27420           38093         Stutsman County, ND

27460                   Jamestown-Dunkirk-Fredonia, NY Micropolitan Statistical Area
27460           36013         Chautauqua County, NY

27500                   Janesville, WI Metropolitan Statistical Area
27500           55105         Rock County, WI

27540                   Jasper, IN Micropolitan Statistical Area
27540           18037         Dubois County, IN
27540           18125         Pike County, IN

27580                   Jayuya, PR Micropolitan Statistical Area
27580           72073         Jayuya Municipio, PR

27620                   Jefferson City, MO Metropolitan Statistical Area
27620           29027         Callaway County, MO
27620           29051         Cole County, MO
27620           29135         Moniteau County, MO
27620           29151         Osage County, MO

27660                   Jennings, LA Micropolitan Statistical Area
27660           22053         Jefferson Davis Parish, LA

27700                   Jesup, GA Micropolitan Statistical Area
27700           13305         Wayne County, GA

27740                   Johnson City, TN Metropolitan Statistical Area
27740           47019         Carter County, TN
27740           47171         Unicoi County, TN
27740           47179         Washington County, TN

27780                   Johnstown, PA Metropolitan Statistical Area
27780           42021         Cambria County, PA

27860                   Jonesboro, AR Metropolitan Statistical Area
27860           05031         Craighead County, AR
27860           05111         Poinsett County, AR

27900                   Joplin, MO Metropolitan Statistical Area
27900           29097         Jasper County, MO
27900           29145         Newton County, MO

27940                   Juneau, AK Micropolitan Statistical Area
27940           02110         Juneau City and Borough, AK

27980                   Kahului-Wailuku, HI Micropolitan Statistical Area
27980           15009         Maui County, HI

28020                   Kalamazoo-Portage, MI Metropolitan Statistical Area
28020           26077         Kalamazoo County, MI
28020           26159         Van Buren County, MI

28060                   Kalispell, MT Micropolitan Statistical Area
28060           30029         Flathead County, MT

28100                   Kankakee-Bradley, IL Metropolitan Statistical Area
28100           17091         Kankakee County, IL

28140                   Kansas City, MO-KS Metropolitan Statistical Area
28140           20059         Franklin County, KS
28140           20091         Johnson County, KS
28140           20103         Leavenworth County, KS
28140           20107         Linn County, KS
28140           20121         Miami County, KS
28140           20209         Wyandotte County, KS
28140           29013         Bates County, MO
28140           29025         Caldwell County, MO
28140           29037         Cass County, MO
28140           29047         Clay County, MO
28140           29049         Clinton County, MO
28140           29095         Jackson County, MO
28140           29107         Lafayette County, MO
28140           29165         Platte County, MO
28140           29177         Ray County, MO

28180                   Kapaa, HI Micropolitan Statistical Area
28180           15007         Kauai County, HI

28260                   Kearney, NE Micropolitan Statistical Area
28260           31019         Buffalo County, NE
28260           31099         Kearney County, NE

28300                   Keene, NH Micropolitan Statistical Area
28300           33005         Cheshire County, NH

28340                   Kendallville, IN Micropolitan Statistical Area
28340           18113         Noble County, IN

28380                   Kennett, MO Micropolitan Statistical Area
28380           29069         Dunklin County, MO

28420                   Kennewick-Pasco-Richland, WA Metropolitan Statistical Area
28420           53005         Benton County, WA
28420           53021         Franklin County, WA

28500                   Kerrville, TX Micropolitan Statistical Area
28500           48265         Kerr County, TX

28540                   Ketchikan, AK Micropolitan Statistical Area
28540           02130         Ketchikan Gateway Borough, AK

28580                   Key West, FL Micropolitan Statistical Area
28580           12087         Monroe County, FL

28620                   Kill Devil Hills, NC Micropolitan Statistical Area
28620           37055         Dare County, NC

28660                   Killeen-Temple-Fort Hood, TX Metropolitan Statistical Area
28660           48027         Bell County, TX
28660           48099         Coryell County, TX
28660           48281         Lampasas County, TX

28700                   Kingsport-Bristol-Bristol, TN-VA Metropolitan Statistical Area
28700           47073         Hawkins County, TN
28700           47163         Sullivan County, TN
28700           51169         Scott County, VA
28700           51191         Washington County, VA
28700           51520         Bristol city, VA

28740                   Kingston, NY Metropolitan Statistical Area
28740           36111         Ulster County, NY

28780                   Kingsville, TX Micropolitan Statistical Area
28780           48261         Kenedy County, TX
28780           48273         Kleberg County, TX

28820                   Kinston, NC Micropolitan Statistical Area
28820           37107         Lenoir County, NC

28860                   Kirksville, MO Micropolitan Statistical Area
28860           29001         Adair County, MO
28860           29197         Schuyler County, MO

28900                   Klamath Falls, OR Micropolitan Statistical Area
28900           41035         Klamath County, OR

28940                   Knoxville, TN Metropolitan Statistical Area
28940           47001         Anderson County, TN
28940           47009         Blount County, TN
28940           47093         Knox County, TN
28940           47105         Loudon County, TN
28940           47173         Union County, TN

28980                   Kodiak, AK Micropolitan Statistical Area
28980           02150         Kodiak Island Borough, AK

29020                   Kokomo, IN Metropolitan Statistical Area
29020           18067         Howard County, IN
29020           18159         Tipton County, IN

29060                   Laconia, NH Micropolitan Statistical Area
29060           33001         Belknap County, NH

29100                   La Crosse, WI-MN Metropolitan Statistical Area
29100           27055         Houston County, MN
29100           55063         La Crosse County, WI

29140                   Lafayette, IN Metropolitan Statistical Area
29140           18007         Benton County, IN
29140           18015         Carroll County, IN
29140           18157         Tippecanoe County, IN

29180                   Lafayette, LA Metropolitan Statistical Area
29180           22055         Lafayette Parish, LA
29180           22099         St. Martin Parish, LA

29220                   La Follette, TN Micropolitan Statistical Area
29220           47013         Campbell County, TN

29260                   La Grande, OR Micropolitan Statistical Area
29260           41061         Union County, OR

29300                   LaGrange, GA Micropolitan Statistical Area
29300           13285         Troup County, GA

29340                   Lake Charles, LA Metropolitan Statistical Area
29340           22019         Calcasieu Parish, LA
29340           22023         Cameron Parish, LA

29380                   Lake City, FL Micropolitan Statistical Area
29380           12023         Columbia County, FL

29420                   Lake Havasu City-Kingman, AZ Metropolitan Statistical Area
29420           04015         Mohave County, AZ

29460                   Lakeland-Winter Haven, FL Metropolitan Statistical Area
29460           12105         Polk County, FL

29500                   Lamesa, TX Micropolitan Statistical Area
29500           48115         Dawson County, TX

29540                   Lancaster, PA Metropolitan Statistical Area
29540           42071         Lancaster County, PA

29580                   Lancaster, SC Micropolitan Statistical Area
29580           45057         Lancaster County, SC

29620                   Lansing-East Lansing, MI Metropolitan Statistical Area
29620           26037         Clinton County, MI
29620           26045         Eaton County, MI
29620           26065         Ingham County, MI

29660                   Laramie, WY Micropolitan Statistical Area
29660           56001         Albany County, WY

29700                   Laredo, TX Metropolitan Statistical Area
29700           48479         Webb County, TX

29740                   Las Cruces, NM Metropolitan Statistical Area
29740           35013         Dona Ana County, NM

29780                   Las Vegas, NM Micropolitan Statistical Area
29780           35047         San Miguel County, NM

29820                   Las Vegas-Paradise, NV Metropolitan Statistical Area
29820           32003         Clark County, NV

29860                   Laurel, MS Micropolitan Statistical Area
29860           28061         Jasper County, MS
29860           28067         Jones County, MS

29900                   Laurinburg, NC Micropolitan Statistical Area
29900           37165         Scotland County, NC

29940                   Lawrence, KS Metropolitan Statistical Area
29940           20045         Douglas County, KS

29980                   Lawrenceburg, TN Micropolitan Statistical Area
29980           47099         Lawrence County, TN

30020                   Lawton, OK Metropolitan Statistical Area
30020           40031         Comanche County, OK

30060                   Lebanon, MO Micropolitan Statistical Area
30060           29105         Laclede County, MO

30100                   Lebanon, NH-VT Micropolitan Statistical Area
30100           33009         Grafton County, NH
30100           50017         Orange County, VT
30100           50027         Windsor County, VT

30140                   Lebanon, PA Metropolitan Statistical Area
30140           42075         Lebanon County, PA

30220                   Levelland, TX Micropolitan Statistical Area
30220           48219         Hockley County, TX

30260                   Lewisburg, PA Micropolitan Statistical Area
30260           42119         Union County, PA

30280                   Lewisburg, TN Micropolitan Statistical Area
30280           47117         Marshall County, TN

30300                   Lewiston, ID-WA Metropolitan Statistical Area
30300           16069         Nez Perce County, ID
30300           53003         Asotin County, WA

30340                   Lewiston-Auburn, ME Metropolitan Statistical Area
30340           23001         Androscoggin County, ME

30380                   Lewistown, PA Micropolitan Statistical Area
30380           42087         Mifflin County, PA

30420                   Lexington, NE Micropolitan Statistical Area
30420           31047         Dawson County, NE
30420           31073         Gosper County, NE

30460                   Lexington-Fayette, KY Metropolitan Statistical Area
30460           21017         Bourbon County, KY
30460           21049         Clark County, KY
30460           21067         Fayette County, KY
30460           21113         Jessamine County, KY
30460           21209         Scott County, KY
30460           21239         Woodford County, KY

30500                   Lexington Park, MD Micropolitan Statistical Area
30500           24037         St. Mary's County, MD

30580                   Liberal, KS Micropolitan Statistical Area
30580           20175         Seward County, KS

30620                   Lima, OH Metropolitan Statistical Area
30620           39003         Allen County, OH

30660                   Lincoln, IL Micropolitan Statistical Area
30660           17107         Logan County, IL

30700                   Lincoln, NE Metropolitan Statistical Area
30700           31109         Lancaster County, NE
30700           31159         Seward County, NE

30740                   Lincolnton, NC Micropolitan Statistical Area
30740           37109         Lincoln County, NC

30780                   Little Rock-North Little Rock-Conway, AR Metropolitan Statistical Area
30780           05045         Faulkner County, AR
30780           05053         Grant County, AR
30780           05085         Lonoke County, AR
30780           05105         Perry County, AR
30780           05119         Pulaski County, AR
30780           05125         Saline County, AR

30820                   Lock Haven, PA Micropolitan Statistical Area
30820           42035         Clinton County, PA

30860                   Logan, UT-ID Metropolitan Statistical Area
30860           16041         Franklin County, ID
30860           49005         Cache County, UT

30900                   Logansport, IN Micropolitan Statistical Area
30900           18017         Cass County, IN

30940                   London, KY Micropolitan Statistical Area
30940           21125         Laurel County, KY

30980                   Longview, TX Metropolitan Statistical Area
30980           48183         Gregg County, TX
30980           48401         Rusk County, TX
30980           48459         Upshur County, TX

31020                   Longview, WA Metropolitan Statistical Area
31020           53015         Cowlitz County, WA

31060                   Los Alamos, NM Micropolitan Statistical Area
31060           35028         Los Alamos County, NM

31100                   Los Angeles-Long Beach-Santa Ana, CA Metropolitan Statistical Area
31100   31084              Los Angeles-Long Beach-Glendale, CA Metropolitan Division
31100   31084   06037         Los Angeles County, CA
31100   42044              Santa Ana-Anaheim-Irvine, CA Metropolitan Division
31100   42044   06059         Orange County, CA

31140                   Louisville/Jefferson County, KY-IN Metropolitan Statistical Area
31140           18019         Clark County, IN
31140           18043         Floyd County, IN
31140           18061         Harrison County, IN
31140           18175         Washington County, IN
31140           21029         Bullitt County, KY
31140           21103         Henry County, KY
31140           21111         Jefferson County, KY
31140           21163         Meade County, KY
31140           21179         Nelson County, KY
31140           21185         Oldham County, KY
31140           21211         Shelby County, KY
31140           21215         Spencer County, KY
31140           21223         Trimble County, KY

31180                   Lubbock, TX Metropolitan Statistical Area
31180           48107         Crosby County, TX
31180           48303         Lubbock County, TX

31260                   Lufkin, TX Micropolitan Statistical Area
31260           48005         Angelina County, TX

31300                   Lumberton, NC Micropolitan Statistical Area
31300           37155         Robeson County, NC

31340                   Lynchburg, VA Metropolitan Statistical Area
31340           51009         Amherst County, VA
31340           51011         Appomattox County, VA
31340           51019         Bedford County, VA
31340           51031         Campbell County, VA
31340           51515         Bedford city, VA
31340           51680         Lynchburg city, VA

31380                   Macomb, IL Micropolitan Statistical Area
31380           17109         McDonough County, IL

31420                   Macon, GA Metropolitan Statistical Area
31420           13021         Bibb County, GA
31420           13079         Crawford County, GA
31420           13169         Jones County, GA
31420           13207         Monroe County, GA
31420           13289         Twiggs County, GA

31460                   Madera-Chowchilla, CA Metropolitan Statistical Area
31460           06039         Madera County, CA

31500                   Madison, IN Micropolitan Statistical Area
31500           18077         Jefferson County, IN

31540                   Madison, WI Metropolitan Statistical Area
31540           55021         Columbia County, WI
31540           55025         Dane County, WI
31540           55049         Iowa County, WI

31580                   Madisonville, KY Micropolitan Statistical Area
31580           21107         Hopkins County, KY

31620                   Magnolia, AR Micropolitan Statistical Area
31620           05027         Columbia County, AR

31660                   Malone, NY Micropolitan Statistical Area
31660           36033         Franklin County, NY

31700                   Manchester-Nashua, NH Metropolitan Statistical Area
31700           33011         Hillsborough County, NH

31740                   Manhattan, KS Metropolitan Statistical Area
31740           20061         Geary County, KS
31740           20149         Pottawatomie County, KS
31740           20161         Riley County, KS

31820                   Manitowoc, WI Micropolitan Statistical Area
31820           55071         Manitowoc County, WI

31860                   Mankato-North Mankato, MN Metropolitan Statistical Area
31860           27013         Blue Earth County, MN
31860           27103         Nicollet County, MN

31900                   Mansfield, OH Metropolitan Statistical Area
31900           39139         Richland County, OH

31920                   Marble Falls, TX Micropolitan Statistical Area
31920           48053         Burnet County, TX

31940                   Marinette, WI-MI Micropolitan Statistical Area
31940           26109         Menominee County, MI
31940           55075         Marinette County, WI

31980                   Marion, IN Micropolitan Statistical Area
31980           18053         Grant County, IN

32020                   Marion, OH Micropolitan Statistical Area
32020           39101         Marion County, OH

32060                   Marion-Herrin, IL Micropolitan Statistical Area
32060           17199         Williamson County, IL

32100                   Marquette, MI Micropolitan Statistical Area
32100           26103         Marquette County, MI

32140                   Marshall, MN Micropolitan Statistical Area
32140           27083         Lyon County, MN

32180                   Marshall, MO Micropolitan Statistical Area
32180           29195         Saline County, MO

32220                   Marshall, TX Micropolitan Statistical Area
32220           48203         Harrison County, TX

32260                   Marshalltown, IA Micropolitan Statistical Area
32260           19127         Marshall County, IA

32270                   Marshfield-Wisconsin Rapids, WI Micropolitan Statistical Area
32270           55141         Wood County, WI

32280                   Martin, TN Micropolitan Statistical Area
32280           47183         Weakley County, TN

32300                   Martinsville, VA Micropolitan Statistical Area
32300           51089         Henry County, VA
32300           51690         Martinsville city, VA

32340                   Maryville, MO Micropolitan Statistical Area
32340           29147         Nodaway County, MO

32380                   Mason City, IA Micropolitan Statistical Area
32380           19033         Cerro Gordo County, IA
32380           19195         Worth County, IA

32420                   Mayagüez, PR Metropolitan Statistical Area
32420           72067         Hormigueros Municipio, PR
32420           72097         Mayagüez Municipio, PR

32460                   Mayfield, KY Micropolitan Statistical Area
32460           21083         Graves County, KY

32500                   Maysville, KY Micropolitan Statistical Area
32500           21135         Lewis County, KY
32500           21161         Mason County, KY

32540                   McAlester, OK Micropolitan Statistical Area
32540           40121         Pittsburg County, OK

32580                   McAllen-Edinburg-Mission, TX Metropolitan Statistical Area
32580           48215         Hidalgo County, TX

32620                   McComb, MS Micropolitan Statistical Area
32620           28005         Amite County, MS
32620           28113         Pike County, MS

32660                   McMinnville, TN Micropolitan Statistical Area
32660           47177         Warren County, TN

32700                   McPherson, KS Micropolitan Statistical Area
32700           20113         McPherson County, KS

32740                   Meadville, PA Micropolitan Statistical Area
32740           42039         Crawford County, PA

32780                   Medford, OR Metropolitan Statistical Area
32780           41029         Jackson County, OR

32820                   Memphis, TN-MS-AR Metropolitan Statistical Area
32820           05035         Crittenden County, AR
32820           28033         DeSoto County, MS
32820           28093         Marshall County, MS
32820           28137         Tate County, MS
32820           28143         Tunica County, MS
32820           47047         Fayette County, TN
32820           47157         Shelby County, TN
32820           47167         Tipton County, TN

32860                   Menomonie, WI Micropolitan Statistical Area
32860           55033         Dunn County, WI

32900                   Merced, CA Metropolitan Statistical Area
32900           06047         Merced County, CA

32940                   Meridian, MS Micropolitan Statistical Area
32940           28023         Clarke County, MS
32940           28069         Kemper County, MS
32940           28075         Lauderdale County, MS

32980                   Merrill, WI Micropolitan Statistical Area
32980           55069         Lincoln County, WI

33020                   Mexico, MO Micropolitan Statistical Area
33020           29007         Audrain County, MO

33060                   Miami, OK Micropolitan Statistical Area
33060           40115         Ottawa County, OK

33100                   Miami-Fort Lauderdale-Pompano Beach, FL Metropolitan Statistical Area
33100   22744              Fort Lauderdale-Pompano Beach-Deerfield Beach, FL Metropolitan Division
33100   22744   12011         Broward County, FL
33100   33124              Miami-Miami Beach-Kendall, FL Metropolitan Division
33100   33124   12086         Miami-Dade County, FL
33100   48424              West Palm Beach-Boca Raton-Boynton Beach, FL Metropolitan Division
33100   48424   12099         Palm Beach County, FL

33140                   Michigan City-La Porte, IN Metropolitan Statistical Area
33140           18091         LaPorte County, IN

33180                   Middlesborough, KY Micropolitan Statistical Area
33180           21013         Bell County, KY

33220                   Midland, MI Micropolitan Statistical Area
33220           26111         Midland County, MI

33260                   Midland, TX Metropolitan Statistical Area
33260           48329         Midland County, TX

33300                   Milledgeville, GA Micropolitan Statistical Area
33300           13009         Baldwin County, GA
33300           13141         Hancock County, GA

33340                   Milwaukee-Waukesha-West Allis, WI Metropolitan Statistical Area
33340           55079         Milwaukee County, WI
33340           55089         Ozaukee County, WI
33340           55131         Washington County, WI
33340           55133         Waukesha County, WI

33380                   Minden, LA Micropolitan Statistical Area
33380           22119         Webster Parish, LA

33420                   Mineral Wells, TX Micropolitan Statistical Area
33420           48363         Palo Pinto County, TX

33460                   Minneapolis-St. Paul-Bloomington, MN-WI Metropolitan Statistical Area
33460           27003         Anoka County, MN
33460           27019         Carver County, MN
33460           27025         Chisago County, MN
33460           27037         Dakota County, MN
33460           27053         Hennepin County, MN
33460           27059         Isanti County, MN
33460           27123         Ramsey County, MN
33460           27139         Scott County, MN
33460           27141         Sherburne County, MN
33460           27163         Washington County, MN
33460           27171         Wright County, MN
33460           55093         Pierce County, WI
33460           55109         St. Croix County, WI

33500                   Minot, ND Micropolitan Statistical Area
33500           38049         McHenry County, ND
33500           38075         Renville County, ND
33500           38101         Ward County, ND

33540                   Missoula, MT Metropolitan Statistical Area
33540           30063         Missoula County, MT

33580                   Mitchell, SD Micropolitan Statistical Area
33580           46035         Davison County, SD
33580           46061         Hanson County, SD

33620                   Moberly, MO Micropolitan Statistical Area
33620           29175         Randolph County, MO

33660                   Mobile, AL Metropolitan Statistical Area
33660           01097         Mobile County, AL

33700                   Modesto, CA Metropolitan Statistical Area
33700           06099         Stanislaus County, CA

33740                   Monroe, LA Metropolitan Statistical Area
33740           22073         Ouachita Parish, LA
33740           22111         Union Parish, LA

33780                   Monroe, MI Metropolitan Statistical Area
33780           26115         Monroe County, MI

33820                   Monroe, WI Micropolitan Statistical Area
33820           55045         Green County, WI

33860                   Montgomery, AL Metropolitan Statistical Area
33860           01001         Autauga County, AL
33860           01051         Elmore County, AL
33860           01085         Lowndes County, AL
33860           01101         Montgomery County, AL

33940                   Montrose, CO Micropolitan Statistical Area
33940           08085         Montrose County, CO

33980                   Morehead City, NC Micropolitan Statistical Area
33980           37031         Carteret County, NC

34020                   Morgan City, LA Micropolitan Statistical Area
34020           22101         St. Mary Parish, LA

34060                   Morgantown, WV Metropolitan Statistical Area
34060           54061         Monongalia County, WV
34060           54077         Preston County, WV

34100                   Morristown, TN Metropolitan Statistical Area
34100           47057         Grainger County, TN
34100           47063         Hamblen County, TN
34100           47089         Jefferson County, TN

34140                   Moscow, ID Micropolitan Statistical Area
34140           16057         Latah County, ID

34180                   Moses Lake, WA Micropolitan Statistical Area
34180           53025         Grant County, WA

34220                   Moultrie, GA Micropolitan Statistical Area
34220           13071         Colquitt County, GA

34260                   Mountain Home, AR Micropolitan Statistical Area
34260           05005         Baxter County, AR

34300                   Mountain Home, ID Micropolitan Statistical Area
34300           16039         Elmore County, ID

34340                   Mount Airy, NC Micropolitan Statistical Area
34340           37171         Surry County, NC

34380                   Mount Pleasant, MI Micropolitan Statistical Area
34380           26073         Isabella County, MI

34420                   Mount Pleasant, TX Micropolitan Statistical Area
34420           48449         Titus County, TX

34460                   Mount Sterling, KY Micropolitan Statistical Area
34460           21011         Bath County, KY
34460           21165         Menifee County, KY
34460           21173         Montgomery County, KY

34500                   Mount Vernon, IL Micropolitan Statistical Area
34500           17065         Hamilton County, IL
34500           17081         Jefferson County, IL

34540                   Mount Vernon, OH Micropolitan Statistical Area
34540           39083         Knox County, OH

34580                   Mount Vernon-Anacortes, WA Metropolitan Statistical Area
34580           53057         Skagit County, WA

34620                   Muncie, IN Metropolitan Statistical Area
34620           18035         Delaware County, IN

34660                   Murray, KY Micropolitan Statistical Area
34660           21035         Calloway County, KY

34700                   Muscatine, IA Micropolitan Statistical Area
34700           19115         Louisa County, IA
34700           19139         Muscatine County, IA

34740                   Muskegon-Norton Shores, MI Metropolitan Statistical Area
34740           26121         Muskegon County, MI

34780                   Muskogee, OK Micropolitan Statistical Area
34780           40101         Muskogee County, OK

34820                   Myrtle Beach-North Myrtle Beach-Conway, SC Metropolitan Statistical Area
34820           45051         Horry County, SC

34860                   Nacogdoches, TX Micropolitan Statistical Area
34860           48347         Nacogdoches County, TX

34900                   Napa, CA Metropolitan Statistical Area
34900           06055         Napa County, CA

34940                   Naples-Marco Island, FL Metropolitan Statistical Area
34940           12021         Collier County, FL

34980                   Nashville-Davidson--Murfreesboro--Franklin, TN Metropolitan Statistical Area
34980           47015         Cannon County, TN
34980           47021         Cheatham County, TN
34980           47037         Davidson County, TN
34980           47043         Dickson County, TN
34980           47081         Hickman County, TN
34980           47111         Macon County, TN
34980           47147         Robertson County, TN
34980           47149         Rutherford County, TN
34980           47159         Smith County, TN
34980           47165         Sumner County, TN
34980           47169         Trousdale County, TN
34980           47187         Williamson County, TN
34980           47189         Wilson County, TN

35020                   Natchez, MS-LA Micropolitan Statistical Area
35020           22029         Concordia Parish, LA
35020           28001         Adams County, MS

35060                   Natchitoches, LA Micropolitan Statistical Area
35060           22069         Natchitoches Parish, LA

35100                   New Bern, NC Micropolitan Statistical Area
35100           37049         Craven County, NC
35100           37103         Jones County, NC
35100           37137         Pamlico County, NC

35140                   Newberry, SC Micropolitan Statistical Area
35140           45071         Newberry County, SC

35220                   New Castle, IN Micropolitan Statistical Area
35220           18065         Henry County, IN

35260                   New Castle, PA Micropolitan Statistical Area
35260           42073         Lawrence County, PA

35300                   New Haven-Milford, CT Metropolitan Statistical Area
35300           09009         New Haven County, CT

35340                   New Iberia, LA Micropolitan Statistical Area
35340           22045         Iberia Parish, LA

35380                   New Orleans-Metairie-Kenner, LA Metropolitan Statistical Area
35380           22051         Jefferson Parish, LA
35380           22071         Orleans Parish, LA
35380           22075         Plaquemines Parish, LA
35380           22087         St. Bernard Parish, LA
35380           22089         St. Charles Parish, LA
35380           22095         St. John the Baptist Parish, LA
35380           22103         St. Tammany Parish, LA

35420                   New Philadelphia-Dover, OH Micropolitan Statistical Area
35420           39157         Tuscarawas County, OH

35460                   Newport, TN Micropolitan Statistical Area
35460           47029         Cocke County, TN

35500                   Newton, IA Micropolitan Statistical Area
35500           19099         Jasper County, IA

35580                   New Ulm, MN Micropolitan Statistical Area
35580           27015         Brown County, MN

35620                   New York-Northern New Jersey-Long Island, NY-NJ-PA Metropolitan Statistical Area
35620   20764              Edison-New Brunswick, NJ Metropolitan Division
35620   20764   34023         Middlesex County, NJ
35620   20764   34025         Monmouth County, NJ
35620   20764   34029         Ocean County, NJ
35620   20764   34035         Somerset County, NJ
35620   35004              Nassau-Suffolk, NY Metropolitan Division
35620   35004   36059         Nassau County, NY
35620   35004   36103         Suffolk County, NY
35620   35644              New York-White Plains-Wayne, NY-NJ Metropolitan Division
35620   35644   34003         Bergen County, NJ
35620   35644   34017         Hudson County, NJ
35620   35644   34031         Passaic County, NJ
35620   35644   36005         Bronx County, NY
35620   35644   36047         Kings County, NY
35620   35644   36061         New York County, NY
35620   35644   36079         Putnam County, NY
35620   35644   36081         Queens County, NY
35620   35644   36085         Richmond County, NY
35620   35644   36087         Rockland County, NY
35620   35644   36119         Westchester County, NY
35620   35084              Newark-Union, NJ-PA Metropolitan Division
35620   35084   34013         Essex County, NJ
35620   35084   34019         Hunterdon County, NJ
35620   35084   34027         Morris County, NJ
35620   35084   34037         Sussex County, NJ
35620   35084   34039         Union County, NJ
35620   35084   42103         Pike County, PA

35660                   Niles-Benton Harbor, MI Metropolitan Statistical Area
35660           26021         Berrien County, MI

35700                   Nogales, AZ Micropolitan Statistical Area
35700           04023         Santa Cruz County, AZ

35740                   Norfolk, NE Micropolitan Statistical Area
35740           31119         Madison County, NE
35740           31139         Pierce County, NE
35740           31167         Stanton County, NE

35820                   North Platte, NE Micropolitan Statistical Area
35820           31111         Lincoln County, NE
35820           31113         Logan County, NE
35820           31117         McPherson County, NE

35840                   North Port-Bradenton-Sarasota, FL Metropolitan Statistical Area
35840           12081         Manatee County, FL
35840           12115         Sarasota County, FL

35860                   North Vernon, IN Micropolitan Statistical Area
35860           18079         Jennings County, IN

35900                   North Wilkesboro, NC Micropolitan Statistical Area
35900           37193         Wilkes County, NC

35940                   Norwalk, OH Micropolitan Statistical Area
35940           39077         Huron County, OH

35980                   Norwich-New London, CT Metropolitan Statistical Area
35980           09011         New London County, CT

36020                   Oak Harbor, WA Micropolitan Statistical Area
36020           53029         Island County, WA

36060                   Oak Hill, WV Micropolitan Statistical Area
36060           54019         Fayette County, WV

36100                   Ocala, FL Metropolitan Statistical Area
36100           12083         Marion County, FL

36140                   Ocean City, NJ Metropolitan Statistical Area
36140           34009         Cape May County, NJ

36180                   Ocean Pines, MD Micropolitan Statistical Area
36180           24047         Worcester County, MD

36220                   Odessa, TX Metropolitan Statistical Area
36220           48135         Ector County, TX

36260                   Ogden-Clearfield, UT Metropolitan Statistical Area
36260           49011         Davis County, UT
36260           49029         Morgan County, UT
36260           49057         Weber County, UT

36300                   Ogdensburg-Massena, NY Micropolitan Statistical Area
36300           36089         St. Lawrence County, NY

36340                   Oil City, PA Micropolitan Statistical Area
36340           42121         Venango County, PA

36380                   Okeechobee, FL Micropolitan Statistical Area
36380           12093         Okeechobee County, FL

36420                   Oklahoma City, OK Metropolitan Statistical Area
36420           40017         Canadian County, OK
36420           40027         Cleveland County, OK
36420           40051         Grady County, OK
36420           40081         Lincoln County, OK
36420           40083         Logan County, OK
36420           40087         McClain County, OK
36420           40109         Oklahoma County, OK

36460                   Olean, NY Micropolitan Statistical Area
36460           36009         Cattaraugus County, NY

36500                   Olympia, WA Metropolitan Statistical Area
36500           53067         Thurston County, WA

36540                   Omaha-Council Bluffs, NE-IA Metropolitan Statistical Area
36540           19085         Harrison County, IA
36540           19129         Mills County, IA
36540           19155         Pottawattamie County, IA
36540           31025         Cass County, NE
36540           31055         Douglas County, NE
36540           31153         Sarpy County, NE
36540           31155         Saunders County, NE
36540           31177         Washington County, NE

36580                   Oneonta, NY Micropolitan Statistical Area
36580           36077         Otsego County, NY

36620                   Ontario, OR-ID Micropolitan Statistical Area
36620           16075         Payette County, ID
36620           41045         Malheur County, OR

36660                   Opelousas-Eunice, LA Micropolitan Statistical Area
36660           22097         St. Landry Parish, LA

36700                   Orangeburg, SC Micropolitan Statistical Area
36700           45075         Orangeburg County, SC

36740                   Orlando-Kissimmee-Sanford, FL Metropolitan Statistical Area
36740           12069         Lake County, FL
36740           12095         Orange County, FL
36740           12097         Osceola County, FL
36740           12117         Seminole County, FL

36780                   Oshkosh-Neenah, WI Metropolitan Statistical Area
36780           55139         Winnebago County, WI

36820                   Oskaloosa, IA Micropolitan Statistical Area
36820           19123         Mahaska County, IA

36860                   Ottawa-Streator, IL Micropolitan Statistical Area
36860           17011         Bureau County, IL
36860           17099         La Salle County, IL
36860           17155         Putnam County, IL

36900                   Ottumwa, IA Micropolitan Statistical Area
36900           19179         Wapello County, IA

36940                   Owatonna, MN Micropolitan Statistical Area
36940           27147         Steele County, MN

36980                   Owensboro, KY Metropolitan Statistical Area
36980           21059         Daviess County, KY
36980           21091         Hancock County, KY
36980           21149         McLean County, KY

37020                   Owosso, MI Micropolitan Statistical Area
37020           26155         Shiawassee County, MI

37060                   Oxford, MS Micropolitan Statistical Area
37060           28071         Lafayette County, MS

37100                   Oxnard-Thousand Oaks-Ventura, CA Metropolitan Statistical Area
37100           06111         Ventura County, CA

37140                   Paducah, KY-IL Micropolitan Statistical Area
37140           17127         Massac County, IL
37140           21007         Ballard County, KY
37140           21139         Livingston County, KY
37140           21145         McCracken County, KY

37220                   Pahrump, NV Micropolitan Statistical Area
37220           32023         Nye County, NV

37260                   Palatka, FL Micropolitan Statistical Area
37260           12107         Putnam County, FL

37300                   Palestine, TX Micropolitan Statistical Area
37300           48001         Anderson County, TX

37340                   Palm Bay-Melbourne-Titusville, FL Metropolitan Statistical Area
37340           12009         Brevard County, FL

37380                   Palm Coast, FL Metropolitan Statistical Area
37380           12035         Flagler County, FL

37420                   Pampa, TX Micropolitan Statistical Area
37420           48179         Gray County, TX
37420           48393         Roberts County, TX

37460                   Panama City-Lynn Haven-Panama City Beach, FL Metropolitan Statistical Area
37460           12005         Bay County, FL

37500                   Paragould, AR Micropolitan Statistical Area
37500           05055         Greene County, AR

37540                   Paris, TN Micropolitan Statistical Area
37540           47079         Henry County, TN

37580                   Paris, TX Micropolitan Statistical Area
37580           48277         Lamar County, TX

37620                   Parkersburg-Marietta-Vienna, WV-OH Metropolitan Statistical Area
37620           39167         Washington County, OH
37620           54073         Pleasants County, WV
37620           54105         Wirt County, WV
37620           54107         Wood County, WV

37660                   Parsons, KS Micropolitan Statistical Area
37660           20099         Labette County, KS

37700                   Pascagoula, MS Metropolitan Statistical Area
37700           28039         George County, MS
37700           28059         Jackson County, MS

37740                   Payson, AZ Micropolitan Statistical Area
37740           04007         Gila County, AZ

37780                   Pecos, TX Micropolitan Statistical Area
37780           48389         Reeves County, TX

37800                   Pella, IA Micropolitan Statistical Area
37800           19125         Marion County, IA

37820                   Pendleton-Hermiston, OR Micropolitan Statistical Area
37820           41049         Morrow County, OR
37820           41059         Umatilla County, OR

37860                   Pensacola-Ferry Pass-Brent, FL Metropolitan Statistical Area
37860           12033         Escambia County, FL
37860           12113         Santa Rosa County, FL

37900                   Peoria, IL Metropolitan Statistical Area
37900           17123         Marshall County, IL
37900           17143         Peoria County, IL
37900           17175         Stark County, IL
37900           17179         Tazewell County, IL
37900           17203         Woodford County, IL

37940                   Peru, IN Micropolitan Statistical Area
37940           18103         Miami County, IN

37980                   Philadelphia-Camden-Wilmington, PA-NJ-DE-MD Metropolitan Statistical Area
37980   15804              Camden, NJ Metropolitan Division
37980   15804   34005         Burlington County, NJ
37980   15804   34007         Camden County, NJ
37980   15804   34015         Gloucester County, NJ
37980   37964              Philadelphia, PA Metropolitan Division
37980   37964   42017         Bucks County, PA
37980   37964   42029         Chester County, PA
37980   37964   42045         Delaware County, PA
37980   37964   42091         Montgomery County, PA
37980   37964   42101         Philadelphia County, PA
37980   48864              Wilmington, DE-MD-NJ Metropolitan Division
37980   48864   10003         New Castle County, DE
37980   48864   24015         Cecil County, MD
37980   48864   34033         Salem County, NJ

38020                   Phoenix Lake-Cedar Ridge, CA Micropolitan Statistical Area
38020           06109         Tuolumne County, CA

38060                   Phoenix-Mesa-Glendale, AZ Metropolitan Statistical Area
38060           04013         Maricopa County, AZ
38060           04021         Pinal County, AZ

38100                   Picayune, MS Micropolitan Statistical Area
38100           28109         Pearl River County, MS

38180                   Pierre, SD Micropolitan Statistical Area
38180           46065         Hughes County, SD
38180           46117         Stanley County, SD

38200                   Pierre Part, LA Micropolitan Statistical Area
38200           22007         Assumption Parish, LA

38220                   Pine Bluff, AR Metropolitan Statistical Area
38220           05025         Cleveland County, AR
38220           05069         Jefferson County, AR
38220           05079         Lincoln County, AR

38260                   Pittsburg, KS Micropolitan Statistical Area
38260           20037         Crawford County, KS

38300                   Pittsburgh, PA Metropolitan Statistical Area
38300           42003         Allegheny County, PA
38300           42005         Armstrong County, PA
38300           42007         Beaver County, PA
38300           42019         Butler County, PA
38300           42051         Fayette County, PA
38300           42125         Washington County, PA
38300           42129         Westmoreland County, PA

38340                   Pittsfield, MA Metropolitan Statistical Area
38340           25003         Berkshire County, MA

38380                   Plainview, TX Micropolitan Statistical Area
38380           48189         Hale County, TX

38420                   Platteville, WI Micropolitan Statistical Area
38420           55043         Grant County, WI

38460                   Plattsburgh, NY Micropolitan Statistical Area
38460           36019         Clinton County, NY

38500                   Plymouth, IN Micropolitan Statistical Area
38500           18099         Marshall County, IN

38540                   Pocatello, ID Metropolitan Statistical Area
38540           16005         Bannock County, ID
38540           16077         Power County, ID

38580                   Point Pleasant, WV-OH Micropolitan Statistical Area
38580           39053         Gallia County, OH
38580           54053         Mason County, WV

38620                   Ponca City, OK Micropolitan Statistical Area
38620           40071         Kay County, OK

38660                   Ponce, PR Metropolitan Statistical Area
38660           72075         Juana Díaz Municipio, PR
38660           72113         Ponce Municipio, PR
38660           72149         Villalba Municipio, PR

38700                   Pontiac, IL Micropolitan Statistical Area
38700           17105         Livingston County, IL

38740                   Poplar Bluff, MO Micropolitan Statistical Area
38740           29023         Butler County, MO

38780                   Portales, NM Micropolitan Statistical Area
38780           35041         Roosevelt County, NM

38820                   Port Angeles, WA Micropolitan Statistical Area
38820           53009         Clallam County, WA

38860                   Portland-South Portland-Biddeford, ME Metropolitan Statistical Area
38860           23005         Cumberland County, ME
38860           23023         Sagadahoc County, ME
38860           23031         York County, ME

38900                   Portland-Vancouver-Hillsboro, OR-WA Metropolitan Statistical Area
38900           41005         Clackamas County, OR
38900           41009         Columbia County, OR
38900           41051         Multnomah County, OR
38900           41067         Washington County, OR
38900           41071         Yamhill County, OR
38900           53011         Clark County, WA
38900           53059         Skamania County, WA

38940                   Port St. Lucie, FL Metropolitan Statistical Area
38940           12085         Martin County, FL
38940           12111         St. Lucie County, FL

39020                   Portsmouth, OH Micropolitan Statistical Area
39020           39145         Scioto County, OH

39060                   Pottsville, PA Micropolitan Statistical Area
39060           42107         Schuylkill County, PA

39100                   Poughkeepsie-Newburgh-Middletown, NY Metropolitan Statistical Area
39100           36027         Dutchess County, NY
39100           36071         Orange County, NY

39140                   Prescott, AZ Metropolitan Statistical Area
39140           04025         Yavapai County, AZ

39220                   Price, UT Micropolitan Statistical Area
39220           49007         Carbon County, UT

39260                   Prineville, OR Micropolitan Statistical Area
39260           41013         Crook County, OR

39300                   Providence-New Bedford-Fall River, RI-MA Metropolitan Statistical Area
39300           25005         Bristol County, MA
39300           44001         Bristol County, RI
39300           44003         Kent County, RI
39300           44005         Newport County, RI
39300           44007         Providence County, RI
39300           44009         Washington County, RI

39340                   Provo-Orem, UT Metropolitan Statistical Area
39340           49023         Juab County, UT
39340           49049         Utah County, UT

39380                   Pueblo, CO Metropolitan Statistical Area
39380           08101         Pueblo County, CO

39420                   Pullman, WA Micropolitan Statistical Area
39420           53075         Whitman County, WA

39460                   Punta Gorda, FL Metropolitan Statistical Area
39460           12015         Charlotte County, FL

39500                   Quincy, IL-MO Micropolitan Statistical Area
39500           17001         Adams County, IL
39500           29111         Lewis County, MO

39540                   Racine, WI Metropolitan Statistical Area
39540           55101         Racine County, WI

39580                   Raleigh-Cary, NC Metropolitan Statistical Area
39580           37069         Franklin County, NC
39580           37101         Johnston County, NC
39580           37183         Wake County, NC

39660                   Rapid City, SD Metropolitan Statistical Area
39660           46093         Meade County, SD
39660           46103         Pennington County, SD

39700                   Raymondville, TX Micropolitan Statistical Area
39700           48489         Willacy County, TX

39740                   Reading, PA Metropolitan Statistical Area
39740           42011         Berks County, PA

39780                   Red Bluff, CA Micropolitan Statistical Area
39780           06103         Tehama County, CA

39820                   Redding, CA Metropolitan Statistical Area
39820           06089         Shasta County, CA

39860                   Red Wing, MN Micropolitan Statistical Area
39860           27049         Goodhue County, MN

39900                   Reno-Sparks, NV Metropolitan Statistical Area
39900           32029         Storey County, NV
39900           32031         Washoe County, NV

39940                   Rexburg, ID Micropolitan Statistical Area
39940           16043         Fremont County, ID
39940           16065         Madison County, ID

39980                   Richmond, IN Micropolitan Statistical Area
39980           18177         Wayne County, IN

40060                   Richmond, VA Metropolitan Statistical Area
40060           51007         Amelia County, VA
40060           51033         Caroline County, VA
40060           51036         Charles City County, VA
40060           51041         Chesterfield County, VA
40060           51049         Cumberland County, VA
40060           51053         Dinwiddie County, VA
40060           51075         Goochland County, VA
40060           51085         Hanover County, VA
40060           51087         Henrico County, VA
40060           51097         King and Queen County, VA
40060           51101         King William County, VA
40060           51109         Louisa County, VA
40060           51127         New Kent County, VA
40060           51145         Powhatan County, VA
40060           51149         Prince George County, VA
40060           51183         Sussex County, VA
40060           51570         Colonial Heights city, VA
40060           51670         Hopewell city, VA
40060           51730         Petersburg city, VA
40060           51760         Richmond city, VA

40080                   Richmond-Berea, KY Micropolitan Statistical Area
40080           21151         Madison County, KY
40080           21203         Rockcastle County, KY

40100                   Rio Grande City-Roma, TX Micropolitan Statistical Area
40100           48427         Starr County, TX

40140                   Riverside-San Bernardino-Ontario, CA Metropolitan Statistical Area
40140           06065         Riverside County, CA
40140           06071         San Bernardino County, CA

40180                   Riverton, WY Micropolitan Statistical Area
40180           56013         Fremont County, WY

40220                   Roanoke, VA Metropolitan Statistical Area
40220           51023         Botetourt County, VA
40220           51045         Craig County, VA
40220           51067         Franklin County, VA
40220           51161         Roanoke County, VA
40220           51770         Roanoke city, VA
40220           51775         Salem city, VA

40260                   Roanoke Rapids, NC Micropolitan Statistical Area
40260           37083         Halifax County, NC
40260           37131         Northampton County, NC

40300                   Rochelle, IL Micropolitan Statistical Area
40300           17141         Ogle County, IL

40340                   Rochester, MN Metropolitan Statistical Area
40340           27039         Dodge County, MN
40340           27109         Olmsted County, MN
40340           27157         Wabasha County, MN

40380                   Rochester, NY Metropolitan Statistical Area
40380           36051         Livingston County, NY
40380           36055         Monroe County, NY
40380           36069         Ontario County, NY
40380           36073         Orleans County, NY
40380           36117         Wayne County, NY

40420                   Rockford, IL Metropolitan Statistical Area
40420           17007         Boone County, IL
40420           17201         Winnebago County, IL

40460                   Rockingham, NC Micropolitan Statistical Area
40460           37153         Richmond County, NC

40500                   Rockland, ME Micropolitan Statistical Area
40500           23013         Knox County, ME

40540                   Rock Springs, WY Micropolitan Statistical Area
40540           56037         Sweetwater County, WY

40580                   Rocky Mount, NC Metropolitan Statistical Area
40580           37065         Edgecombe County, NC
40580           37127         Nash County, NC

40620                   Rolla, MO Micropolitan Statistical Area
40620           29161         Phelps County, MO

40660                   Rome, GA Metropolitan Statistical Area
40660           13115         Floyd County, GA

40700                   Roseburg, OR Micropolitan Statistical Area
40700           41019         Douglas County, OR

40740                   Roswell, NM Micropolitan Statistical Area
40740           35005         Chaves County, NM

40760                   Ruidoso, NM Micropolitan Statistical Area
40760           35027         Lincoln County, NM

40780                   Russellville, AR Micropolitan Statistical Area
40780           05115         Pope County, AR
40780           05149         Yell County, AR

40820                   Ruston, LA Micropolitan Statistical Area
40820           22049         Jackson Parish, LA
40820           22061         Lincoln Parish, LA

40860                   Rutland, VT Micropolitan Statistical Area
40860           50021         Rutland County, VT

40900                   Sacramento--Arden-Arcade--Roseville, CA Metropolitan Statistical Area
40900           06017         El Dorado County, CA
40900           06061         Placer County, CA
40900           06067         Sacramento County, CA
40900           06113         Yolo County, CA

40940                   Safford, AZ Micropolitan Statistical Area
40940           04009         Graham County, AZ
40940           04011         Greenlee County, AZ

40980                   Saginaw-Saginaw Township North, MI Metropolitan Statistical Area
40980           26145         Saginaw County, MI

41060                   St. Cloud, MN Metropolitan Statistical Area
41060           27009         Benton County, MN
41060           27145         Stearns County, MN

41100                   St. George, UT Metropolitan Statistical Area
41100           49053         Washington County, UT

41140                   St. Joseph, MO-KS Metropolitan Statistical Area
41140           20043         Doniphan County, KS
41140           29003         Andrew County, MO
41140           29021         Buchanan County, MO
41140           29063         DeKalb County, MO

41180                   St. Louis, MO-IL Metropolitan Statistical Area
41180           17005         Bond County, IL
41180           17013         Calhoun County, IL
41180           17027         Clinton County, IL
41180           17083         Jersey County, IL
41180           17117         Macoupin County, IL
41180           17119         Madison County, IL
41180           17133         Monroe County, IL
41180           17163         St. Clair County, IL
41180           29055         Crawford County, MO (pt.)*
41180           29071         Franklin County, MO
41180           29099         Jefferson County, MO
41180           29113         Lincoln County, MO
41180           29183         St. Charles County, MO
41180           29189         St. Louis County, MO
41180           29219         Warren County, MO
41180           29221         Washington County, MO
41180           29510         St. Louis city, MO

41220                   St. Marys, GA Micropolitan Statistical Area
41220           13039         Camden County, GA

41260                   St. Marys, PA Micropolitan Statistical Area
41260           42047         Elk County, PA

41420                   Salem, OR Metropolitan Statistical Area
41420           41047         Marion County, OR
41420           41053         Polk County, OR

41460                   Salina, KS Micropolitan Statistical Area
41460           20143         Ottawa County, KS
41460           20169         Saline County, KS

41500                   Salinas, CA Metropolitan Statistical Area
41500           06053         Monterey County, CA

41540                   Salisbury, MD Metropolitan Statistical Area
41540           24039         Somerset County, MD
41540           24045         Wicomico County, MD

41580                   Salisbury, NC Micropolitan Statistical Area
41580           37159         Rowan County, NC

41620                   Salt Lake City, UT Metropolitan Statistical Area
41620           49035         Salt Lake County, UT
41620           49043         Summit County, UT
41620           49045         Tooele County, UT

41660                   San Angelo, TX Metropolitan Statistical Area
41660           48235         Irion County, TX
41660           48451         Tom Green County, TX

41700                   San Antonio-New Braunfels, TX Metropolitan Statistical Area
41700           48013         Atascosa County, TX
41700           48019         Bandera County, TX
41700           48029         Bexar County, TX
41700           48091         Comal County, TX
41700           48187         Guadalupe County, TX
41700           48259         Kendall County, TX
41700           48325         Medina County, TX
41700           48493         Wilson County, TX

41740                   San Diego-Carlsbad-San Marcos, CA Metropolitan Statistical Area
41740           06073         San Diego County, CA

41780                   Sandusky, OH Metropolitan Statistical Area
41780           39043         Erie County, OH

41820                   Sanford, NC Micropolitan Statistical Area
41820           37105         Lee County, NC

41860                   San Francisco-Oakland-Fremont, CA Metropolitan Statistical Area
41860   36084              Oakland-Fremont-Hayward, CA Metropolitan Division
41860   36084   06001         Alameda County, CA
41860   36084   06013         Contra Costa County, CA
41860   41884              San Francisco-San Mateo-Redwood City, CA Metropolitan Division
41860   41884   06041         Marin County, CA
41860   41884   06075         San Francisco County, CA
41860   41884   06081         San Mateo County, CA

41900                   San Germán-Cabo Rojo, PR Metropolitan Statistical Area
41900           72023         Cabo Rojo Municipio, PR
41900           72079         Lajas Municipio, PR
41900           72121         Sabana Grande Municipio, PR
41900           72125         San Germán Municipio, PR

41940                   San Jose-Sunnyvale-Santa Clara, CA Metropolitan Statistical Area
41940           06069         San Benito County, CA
41940           06085         Santa Clara County, CA

41980                   San Juan-Caguas-Guaynabo, PR Metropolitan Statistical Area
41980           72007         Aguas Buenas Municipio, PR
41980           72009         Aibonito Municipio, PR
41980           72013         Arecibo Municipio, PR
41980           72017         Barceloneta Municipio, PR
41980           72019         Barranquitas Municipio, PR
41980           72021         Bayamón Municipio, PR
41980           72025         Caguas Municipio, PR
41980           72027         Camuy Municipio, PR
41980           72029         Canóvanas Municipio, PR
41980           72031         Carolina Municipio, PR
41980           72033         Cataño Municipio, PR
41980           72035         Cayey Municipio, PR
41980           72039         Ciales Municipio, PR
41980           72041         Cidra Municipio, PR
41980           72045         Comerío Municipio, PR
41980           72047         Corozal Municipio, PR
41980           72051         Dorado Municipio, PR
41980           72054         Florida Municipio, PR
41980           72061         Guaynabo Municipio, PR
41980           72063         Gurabo Municipio, PR
41980           72065         Hatillo Municipio, PR
41980           72069         Humacao Municipio, PR
41980           72077         Juncos Municipio, PR
41980           72085         Las Piedras Municipio, PR
41980           72087         Loíza Municipio, PR
41980           72091         Manatí Municipio, PR
41980           72095         Maunabo Municipio, PR
41980           72101         Morovis Municipio, PR
41980           72103         Naguabo Municipio, PR
41980           72105         Naranjito Municipio, PR
41980           72107         Orocovis Municipio, PR
41980           72115         Quebradillas Municipio, PR
41980           72119         Río Grande Municipio, PR
41980           72127         San Juan Municipio, PR
41980           72129         San Lorenzo Municipio, PR
41980           72135         Toa Alta Municipio, PR
41980           72137         Toa Baja Municipio, PR
41980           72139         Trujillo Alto Municipio, PR
41980           72143         Vega Alta Municipio, PR
41980           72145         Vega Baja Municipio, PR
41980           72151         Yabucoa Municipio, PR

42020                   San Luis Obispo-Paso Robles, CA Metropolitan Statistical Area
42020           06079         San Luis Obispo County, CA

42060                   Santa Barbara-Santa Maria-Goleta, CA Metropolitan Statistical Area
42060           06083         Santa Barbara County, CA

42100                   Santa Cruz-Watsonville, CA Metropolitan Statistical Area
42100           06087         Santa Cruz County, CA

42140                   Santa Fe, NM Metropolitan Statistical Area
42140           35049         Santa Fe County, NM

42180                   Santa Isabel, PR Micropolitan Statistical Area
42180           72133         Santa Isabel Municipio, PR

42220                   Santa Rosa-Petaluma, CA Metropolitan Statistical Area
42220           06097         Sonoma County, CA

42300                   Sault Ste. Marie, MI Micropolitan Statistical Area
42300           26033         Chippewa County, MI

42340                   Savannah, GA Metropolitan Statistical Area
42340           13029         Bryan County, GA
42340           13051         Chatham County, GA
42340           13103         Effingham County, GA

42380                   Sayre, PA Micropolitan Statistical Area
42380           42015         Bradford County, PA

42420                   Scottsbluff, NE Micropolitan Statistical Area
42420           31007         Banner County, NE
42420           31157         Scotts Bluff County, NE

42460                   Scottsboro, AL Micropolitan Statistical Area
42460           01071         Jackson County, AL

42500                   Scottsburg, IN Micropolitan Statistical Area
42500           18143         Scott County, IN

42540                   Scranton--Wilkes-Barre, PA Metropolitan Statistical Area
42540           42069         Lackawanna County, PA
42540           42079         Luzerne County, PA
42540           42131         Wyoming County, PA

42580                   Seaford, DE Micropolitan Statistical Area
42580           10005         Sussex County, DE

42620                   Searcy, AR Micropolitan Statistical Area
42620           05145         White County, AR

42660                   Seattle-Tacoma-Bellevue, WA Metropolitan Statistical Area
42660   42644              Seattle-Bellevue-Everett, WA Metropolitan Division
42660   42644   53033         King County, WA
42660   42644   53061         Snohomish County, WA
42660   45104              Tacoma, WA Metropolitan Division
42660   45104   53053         Pierce County, WA

42680                   Sebastian-Vero Beach, FL Metropolitan Statistical Area
42680           12061         Indian River County, FL

42700                   Sebring, FL Micropolitan Statistical Area
42700           12055         Highlands County, FL

42740                   Sedalia, MO Micropolitan Statistical Area
42740           29159         Pettis County, MO

42780                   Selinsgrove, PA Micropolitan Statistical Area
42780           42109         Snyder County, PA

42820                   Selma, AL Micropolitan Statistical Area
42820           01047         Dallas County, AL

42860                   Seneca, SC Micropolitan Statistical Area
42860           45073         Oconee County, SC

42900                   Seneca Falls, NY Micropolitan Statistical Area
42900           36099         Seneca County, NY

42940                   Sevierville, TN Micropolitan Statistical Area
42940           47155         Sevier County, TN

42980                   Seymour, IN Micropolitan Statistical Area
42980           18071         Jackson County, IN

43060                   Shawnee, OK Micropolitan Statistical Area
43060           40125         Pottawatomie County, OK

43100                   Sheboygan, WI Metropolitan Statistical Area
43100           55117         Sheboygan County, WI

43140                   Shelby, NC Micropolitan Statistical Area
43140           37045         Cleveland County, NC

43180                   Shelbyville, TN Micropolitan Statistical Area
43180           47003         Bedford County, TN

43220                   Shelton, WA Micropolitan Statistical Area
43220           53045         Mason County, WA

43260                   Sheridan, WY Micropolitan Statistical Area
43260           56033         Sheridan County, WY

43300                   Sherman-Denison, TX Metropolitan Statistical Area
43300           48181         Grayson County, TX

43320                   Show Low, AZ Micropolitan Statistical Area
43320           04017         Navajo County, AZ

43340                   Shreveport-Bossier City, LA Metropolitan Statistical Area
43340           22015         Bossier Parish, LA
43340           22017         Caddo Parish, LA
43340           22031         De Soto Parish, LA

43380                   Sidney, OH Micropolitan Statistical Area
43380           39149         Shelby County, OH

43420                   Sierra Vista-Douglas, AZ Micropolitan Statistical Area
43420           04003         Cochise County, AZ

43460                   Sikeston, MO Micropolitan Statistical Area
43460           29201         Scott County, MO

43500                   Silver City, NM Micropolitan Statistical Area
43500           35017         Grant County, NM

43540                   Silverthorne, CO Micropolitan Statistical Area
43540           08117         Summit County, CO

43580                   Sioux City, IA-NE-SD Metropolitan Statistical Area
43580           19193         Woodbury County, IA
43580           31043         Dakota County, NE
43580           31051         Dixon County, NE
43580           46127         Union County, SD

43620                   Sioux Falls, SD Metropolitan Statistical Area
43620           46083         Lincoln County, SD
43620           46087         McCook County, SD
43620           46099         Minnehaha County, SD
43620           46125         Turner County, SD

43660                   Snyder, TX Micropolitan Statistical Area
43660           48415         Scurry County, TX

43700                   Somerset, KY Micropolitan Statistical Area
43700           21199         Pulaski County, KY

43740                   Somerset, PA Micropolitan Statistical Area
43740           42111         Somerset County, PA

43780                   South Bend-Mishawaka, IN-MI Metropolitan Statistical Area
43780           18141         St. Joseph County, IN
43780           26027         Cass County, MI

43860                   Southern Pines-Pinehurst, NC Micropolitan Statistical Area
43860           37125         Moore County, NC

43900                   Spartanburg, SC Metropolitan Statistical Area
43900           45083         Spartanburg County, SC

43940                   Spearfish, SD Micropolitan Statistical Area
43940           46081         Lawrence County, SD

43980                   Spencer, IA Micropolitan Statistical Area
43980           19041         Clay County, IA

44020                   Spirit Lake, IA Micropolitan Statistical Area
44020           19059         Dickinson County, IA

44060                   Spokane, WA Metropolitan Statistical Area
44060           53063         Spokane County, WA

44100                   Springfield, IL Metropolitan Statistical Area
44100           17129         Menard County, IL
44100           17167         Sangamon County, IL

44140                   Springfield, MA Metropolitan Statistical Area
44140           25011         Franklin County, MA
44140           25013         Hampden County, MA
44140           25015         Hampshire County, MA

44180                   Springfield, MO Metropolitan Statistical Area
44180           29043         Christian County, MO
44180           29059         Dallas County, MO
44180           29077         Greene County, MO
44180           29167         Polk County, MO
44180           29225         Webster County, MO

44220                   Springfield, OH Metropolitan Statistical Area
44220           39023         Clark County, OH

44260                   Starkville, MS Micropolitan Statistical Area
44260           28105         Oktibbeha County, MS

44300                   State College, PA Metropolitan Statistical Area
44300           42027         Centre County, PA

44340                   Statesboro, GA Micropolitan Statistical Area
44340           13031         Bulloch County, GA

44380                   Statesville-Mooresville, NC Micropolitan Statistical Area
44380           37097         Iredell County, NC

44420                   Staunton-Waynesboro, VA Micropolitan Statistical Area
44420           51015         Augusta County, VA
44420           51790         Staunton city, VA
44420           51820         Waynesboro city, VA

44500                   Stephenville, TX Micropolitan Statistical Area
44500           48143         Erath County, TX

44540                   Sterling, CO Micropolitan Statistical Area
44540           08075         Logan County, CO

44580                   Sterling, IL Micropolitan Statistical Area
44580           17195         Whiteside County, IL

44600                   Steubenville-Weirton, OH-WV Metropolitan Statistical Area
44600           39081         Jefferson County, OH
44600           54009         Brooke County, WV
44600           54029         Hancock County, WV

44620                   Stevens Point, WI Micropolitan Statistical Area
44620           55097         Portage County, WI

44660                   Stillwater, OK Micropolitan Statistical Area
44660           40119         Payne County, OK

44700                   Stockton, CA Metropolitan Statistical Area
44700           06077         San Joaquin County, CA

44740                   Storm Lake, IA Micropolitan Statistical Area
44740           19021         Buena Vista County, IA

44780                   Sturgis, MI Micropolitan Statistical Area
44780           26149         St. Joseph County, MI

44860                   Sulphur Springs, TX Micropolitan Statistical Area
44860           48223         Hopkins County, TX

44900                   Summerville, GA Micropolitan Statistical Area
44900           13055         Chattooga County, GA

44940                   Sumter, SC Metropolitan Statistical Area
44940           45085         Sumter County, SC

44980                   Sunbury, PA Micropolitan Statistical Area
44980           42097         Northumberland County, PA

45000                   Susanville, CA Micropolitan Statistical Area
45000           06035         Lassen County, CA

45020                   Sweetwater, TX Micropolitan Statistical Area
45020           48353         Nolan County, TX

45060                   Syracuse, NY Metropolitan Statistical Area
45060           36053         Madison County, NY
45060           36067         Onondaga County, NY
45060           36075         Oswego County, NY

45140                   Tahlequah, OK Micropolitan Statistical Area
45140           40021         Cherokee County, OK

45180                   Talladega-Sylacauga, AL Micropolitan Statistical Area
45180           01121         Talladega County, AL

45220                   Tallahassee, FL Metropolitan Statistical Area
45220           12039         Gadsden County, FL
45220           12065         Jefferson County, FL
45220           12073         Leon County, FL
45220           12129         Wakulla County, FL

45260                   Tallulah, LA Micropolitan Statistical Area
45260           22065         Madison Parish, LA

45300                   Tampa-St. Petersburg-Clearwater, FL Metropolitan Statistical Area
45300           12053         Hernando County, FL
45300           12057         Hillsborough County, FL
45300           12101         Pasco County, FL
45300           12103         Pinellas County, FL

45340                   Taos, NM Micropolitan Statistical Area
45340           35055         Taos County, NM

45380                   Taylorville, IL Micropolitan Statistical Area
45380           17021         Christian County, IL

45460                   Terre Haute, IN Metropolitan Statistical Area
45460           18021         Clay County, IN
45460           18153         Sullivan County, IN
45460           18165         Vermillion County, IN
45460           18167         Vigo County, IN

45500                   Texarkana, TX-Texarkana, AR Metropolitan Statistical Area
45500           05091         Miller County, AR
45500           48037         Bowie County, TX

45520                   The Dalles, OR Micropolitan Statistical Area
45520           41065         Wasco County, OR

45540                   The Villages, FL Micropolitan Statistical Area
45540           12119         Sumter County, FL

45580                   Thomaston, GA Micropolitan Statistical Area
45580           13293         Upson County, GA

45620                   Thomasville, GA Micropolitan Statistical Area
45620           13275         Thomas County, GA

45640                   Thomasville-Lexington, NC Micropolitan Statistical Area
45640           37057         Davidson County, NC

45660                   Tiffin, OH Micropolitan Statistical Area
45660           39147         Seneca County, OH

45700                   Tifton, GA Micropolitan Statistical Area
45700           13277         Tift County, GA

45740                   Toccoa, GA Micropolitan Statistical Area
45740           13257         Stephens County, GA

45780                   Toledo, OH Metropolitan Statistical Area
45780           39051         Fulton County, OH
45780           39095         Lucas County, OH
45780           39123         Ottawa County, OH
45780           39173         Wood County, OH

45820                   Topeka, KS Metropolitan Statistical Area
45820           20085         Jackson County, KS
45820           20087         Jefferson County, KS
45820           20139         Osage County, KS
45820           20177         Shawnee County, KS
45820           20197         Wabaunsee County, KS

45860                   Torrington, CT Micropolitan Statistical Area
45860           09005         Litchfield County, CT

45900                   Traverse City, MI Micropolitan Statistical Area
45900           26019         Benzie County, MI
45900           26055         Grand Traverse County, MI
45900           26079         Kalkaska County, MI
45900           26089         Leelanau County, MI

45940                   Trenton-Ewing, NJ Metropolitan Statistical Area
45940           34021         Mercer County, NJ

45980                   Troy, AL Micropolitan Statistical Area
45980           01109         Pike County, AL

46020                   Truckee-Grass Valley, CA Micropolitan Statistical Area
46020           06057         Nevada County, CA

46060                   Tucson, AZ Metropolitan Statistical Area
46060           04019         Pima County, AZ

46100                   Tullahoma, TN Micropolitan Statistical Area
46100           47031         Coffee County, TN
46100           47051         Franklin County, TN
46100           47127         Moore County, TN

46140                   Tulsa, OK Metropolitan Statistical Area
46140           40037         Creek County, OK
46140           40111         Okmulgee County, OK
46140           40113         Osage County, OK
46140           40117         Pawnee County, OK
46140           40131         Rogers County, OK
46140           40143         Tulsa County, OK
46140           40145         Wagoner County, OK

46180                   Tupelo, MS Micropolitan Statistical Area
46180           28057         Itawamba County, MS
46180           28081         Lee County, MS
46180           28115         Pontotoc County, MS

46220                   Tuscaloosa, AL Metropolitan Statistical Area
46220           01063         Greene County, AL
46220           01065         Hale County, AL
46220           01125         Tuscaloosa County, AL

46260                   Tuskegee, AL Micropolitan Statistical Area
46260           01087         Macon County, AL

46300                   Twin Falls, ID Micropolitan Statistical Area
46300           16053         Jerome County, ID
46300           16083         Twin Falls County, ID

46340                   Tyler, TX Metropolitan Statistical Area
46340           48423         Smith County, TX

46380                   Ukiah, CA Micropolitan Statistical Area
46380           06045         Mendocino County, CA

46420                   Union, SC Micropolitan Statistical Area
46420           45087         Union County, SC

46460                   Union City, TN-KY Micropolitan Statistical Area
46460           21075         Fulton County, KY
46460           47131         Obion County, TN

46500                   Urbana, OH Micropolitan Statistical Area
46500           39021         Champaign County, OH

46540                   Utica-Rome, NY Metropolitan Statistical Area
46540           36043         Herkimer County, NY
46540           36065         Oneida County, NY

46580                   Utuado, PR Micropolitan Statistical Area
46580           72141         Utuado Municipio, PR

46620                   Uvalde, TX Micropolitan Statistical Area
46620           48463         Uvalde County, TX

46660                   Valdosta, GA Metropolitan Statistical Area
46660           13027         Brooks County, GA
46660           13101         Echols County, GA
46660           13173         Lanier County, GA
46660           13185         Lowndes County, GA

46700                   Vallejo-Fairfield, CA Metropolitan Statistical Area
46700           06095         Solano County, CA

46740                   Valley, AL Micropolitan Statistical Area
46740           01017         Chambers County, AL

46780                   Van Wert, OH Micropolitan Statistical Area
46780           39161         Van Wert County, OH

46820                   Vermillion, SD Micropolitan Statistical Area
46820           46027         Clay County, SD

46860                   Vernal, UT Micropolitan Statistical Area
46860           49047         Uintah County, UT

46900                   Vernon, TX Micropolitan Statistical Area
46900           48487         Wilbarger County, TX

46980                   Vicksburg, MS Micropolitan Statistical Area
46980           28149         Warren County, MS

47020                   Victoria, TX Metropolitan Statistical Area
47020           48057         Calhoun County, TX
47020           48175         Goliad County, TX
47020           48469         Victoria County, TX

47080                   Vidalia, GA Micropolitan Statistical Area
47080           13209         Montgomery County, GA
47080           13279         Toombs County, GA

47180                   Vincennes, IN Micropolitan Statistical Area
47180           18083         Knox County, IN

47220                   Vineland-Millville-Bridgeton, NJ Metropolitan Statistical Area
47220           34011         Cumberland County, NJ

47260                   Virginia Beach-Norfolk-Newport News, VA-NC Metropolitan Statistical Area
47260           37053         Currituck County, NC
47260           51073         Gloucester County, VA
47260           51093         Isle of Wight County, VA
47260           51095         James City County, VA
47260           51115         Mathews County, VA
47260           51181         Surry County, VA
47260           51199         York County, VA
47260           51550         Chesapeake city, VA
47260           51650         Hampton city, VA
47260           51700         Newport News city, VA
47260           51710         Norfolk city, VA
47260           51735         Poquoson city, VA
47260           51740         Portsmouth city, VA
47260           51800         Suffolk city, VA
47260           51810         Virginia Beach city, VA
47260           51830         Williamsburg city, VA

47300                   Visalia-Porterville, CA Metropolitan Statistical Area
47300           06107         Tulare County, CA

47340                   Wabash, IN Micropolitan Statistical Area
47340           18169         Wabash County, IN

47380                   Waco, TX Metropolitan Statistical Area
47380           48309         McLennan County, TX

47420                   Wahpeton, ND-MN Micropolitan Statistical Area
47420           27167         Wilkin County, MN
47420           38077         Richland County, ND

47460                   Walla Walla, WA Micropolitan Statistical Area
47460           53071         Walla Walla County, WA

47500                   Walterboro, SC Micropolitan Statistical Area
47500           45029         Colleton County, SC

47540                   Wapakoneta, OH Micropolitan Statistical Area
47540           39011         Auglaize County, OH

47580                   Warner Robins, GA Metropolitan Statistical Area
47580           13153         Houston County, GA

47620                   Warren, PA Micropolitan Statistical Area
47620           42123         Warren County, PA

47660                   Warrensburg, MO Micropolitan Statistical Area
47660           29101         Johnson County, MO

47700                   Warsaw, IN Micropolitan Statistical Area
47700           18085         Kosciusko County, IN

47780                   Washington, IN Micropolitan Statistical Area
47780           18027         Daviess County, IN

47820                   Washington, NC Micropolitan Statistical Area
47820           37013         Beaufort County, NC

47900                   Washington-Arlington-Alexandria, DC-VA-MD-WV Metropolitan Statistical Area
47900   13644              Bethesda-Rockville-Frederick, MD Metropolitan Division
47900   13644   24021         Frederick County, MD
47900   13644   24031         Montgomery County, MD
47900   47894              Washington-Arlington-Alexandria, DC-VA-MD-WV Metropolitan Division
47900   47894   11001         District of Columbia, DC
47900   47894   24009         Calvert County, MD
47900   47894   24017         Charles County, MD
47900   47894   24033         Prince George's County, MD
47900   47894   51013         Arlington County, VA
47900   47894   51043         Clarke County, VA
47900   47894   51059         Fairfax County, VA
47900   47894   51061         Fauquier County, VA
47900   47894   51107         Loudoun County, VA
47900   47894   51153         Prince William County, VA
47900   47894   51177         Spotsylvania County, VA
47900   47894   51179         Stafford County, VA
47900   47894   51187         Warren County, VA
47900   47894   51510         Alexandria city, VA
47900   47894   51600         Fairfax city, VA
47900   47894   51610         Falls Church city, VA
47900   47894   51630         Fredericksburg city, VA
47900   47894   51683         Manassas city, VA
47900   47894   51685         Manassas Park city, VA
47900   47894   54037         Jefferson County, WV

47920                   Washington Court House, OH Micropolitan Statistical Area
47920           39047         Fayette County, OH

47940                   Waterloo-Cedar Falls, IA Metropolitan Statistical Area
47940           19013         Black Hawk County, IA
47940           19017         Bremer County, IA
47940           19075         Grundy County, IA

47980                   Watertown, SD Micropolitan Statistical Area
47980           46029         Codington County, SD
47980           46057         Hamlin County, SD

48020                   Watertown-Fort Atkinson, WI Micropolitan Statistical Area
48020           55055         Jefferson County, WI

48060                   Watertown-Fort Drum, NY Micropolitan Statistical Area
48060           36045         Jefferson County, NY

48100                   Wauchula, FL Micropolitan Statistical Area
48100           12049         Hardee County, FL

48140                   Wausau, WI Metropolitan Statistical Area
48140           55073         Marathon County, WI

48180                   Waycross, GA Micropolitan Statistical Area
48180           13229         Pierce County, GA
48180           13299         Ware County, GA

48220                   Weatherford, OK Micropolitan Statistical Area
48220           40039         Custer County, OK

48300                   Wenatchee-East Wenatchee, WA Metropolitan Statistical Area
48300           53007         Chelan County, WA
48300           53017         Douglas County, WA

48460                   West Plains, MO Micropolitan Statistical Area
48460           29091         Howell County, MO

48500                   West Point, MS Micropolitan Statistical Area
48500           28025         Clay County, MS

48540                   Wheeling, WV-OH Metropolitan Statistical Area
48540           39013         Belmont County, OH
48540           54051         Marshall County, WV
48540           54069         Ohio County, WV

48580                   Whitewater, WI Micropolitan Statistical Area
48580           55127         Walworth County, WI

48620                   Wichita, KS Metropolitan Statistical Area
48620           20015         Butler County, KS
48620           20079         Harvey County, KS
48620           20173         Sedgwick County, KS
48620           20191         Sumner County, KS

48660                   Wichita Falls, TX Metropolitan Statistical Area
48660           48009         Archer County, TX
48660           48077         Clay County, TX
48660           48485         Wichita County, TX

48700                   Williamsport, PA Metropolitan Statistical Area
48700           42081         Lycoming County, PA

48740                   Willimantic, CT Micropolitan Statistical Area
48740           09015         Windham County, CT

48780                   Williston, ND Micropolitan Statistical Area
48780           38105         Williams County, ND

48820                   Willmar, MN Micropolitan Statistical Area
48820           27067         Kandiyohi County, MN

48900                   Wilmington, NC Metropolitan Statistical Area
48900           37019         Brunswick County, NC
48900           37129         New Hanover County, NC
48900           37141         Pender County, NC

48940                   Wilmington, OH Micropolitan Statistical Area
48940           39027         Clinton County, OH

48980                   Wilson, NC Micropolitan Statistical Area
48980           37195         Wilson County, NC

49020                   Winchester, VA-WV Metropolitan Statistical Area
49020           51069         Frederick County, VA
49020           51840         Winchester city, VA
49020           54027         Hampshire County, WV

49060                   Winfield, KS Micropolitan Statistical Area
49060           20035         Cowley County, KS

49100                   Winona, MN Micropolitan Statistical Area
49100           27169         Winona County, MN

49180                   Winston-Salem, NC Metropolitan Statistical Area
49180           37059         Davie County, NC
49180           37067         Forsyth County, NC
49180           37169         Stokes County, NC
49180           37197         Yadkin County, NC

49260                   Woodward, OK Micropolitan Statistical Area
49260           40153         Woodward County, OK

49300                   Wooster, OH Micropolitan Statistical Area
49300           39169         Wayne County, OH

49340                   Worcester, MA Metropolitan Statistical Area
49340           25027         Worcester County, MA

49380                   Worthington, MN Micropolitan Statistical Area
49380           27105         Nobles County, MN

49420                   Yakima, WA Metropolitan Statistical Area
49420           53077         Yakima County, WA

49460                   Yankton, SD Micropolitan Statistical Area
49460           46135         Yankton County, SD

49500                   Yauco, PR Metropolitan Statistical Area
49500           72055         Guánica Municipio, PR
49500           72059         Guayanilla Municipio, PR
49500           72111         Peñuelas Municipio, PR
49500           72153         Yauco Municipio, PR

49540                   Yazoo City, MS Micropolitan Statistical Area
49540           28163         Yazoo County, MS

49620                   York-Hanover, PA Metropolitan Statistical Area
49620           42133         York County, PA

49660                   Youngstown-Warren-Boardman, OH-PA Metropolitan Statistical Area
49660           39099         Mahoning County, OH
49660           39155         Trumbull County, OH
49660           42085         Mercer County, PA

49700                   Yuba City, CA Metropolitan Statistical Area
49700           06101         Sutter County, CA
49700           06115         Yuba County, CA

49740                   Yuma, AZ Metropolitan Statistical Area
49740           04027         Yuma County, AZ

49780                   Zanesville, OH Micropolitan Statistical Area
49780           39119         Muskingum County, OH

