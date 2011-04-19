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
        next unless $row =~ /^([0-9]{5})\s+([A-Za-z, \-]{5,80}) .{3}ropolitan Statistical Area/;
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
