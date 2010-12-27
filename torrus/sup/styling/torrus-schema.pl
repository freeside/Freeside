# RRDtool graph Colors and Lines Profile.
# You are encouraged to create your own copy and reference it
# with $Torrus::Renderer::stylingProfile in your torrus-siteconfig.pl
# or better define your amendments in Torrus::Renderer::stylingProfileOverlay

# $Id: torrus-schema.pl,v 1.1 2010-12-27 00:04:04 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

%Torrus::Renderer::graphStyles =
    (
     'SingleGraph'     => {
         'color' => '##blue',
         'line'  => 'LINE2'
         },
     'HWBoundary'     => {
         'color' => '##red',
         'line'  => 'LINE1'
         },
     'HWFailure'      => {
         'color' => '##moccasin'
         },
     'HruleMin'       => {
         'color' => '##darkmagenta'
         },
     'HruleNormal'    => {
         'color' => '##seagreen'
         },
     'HruleMax'       => {
         'color' => '##darkmagenta'
         },
     'BpsIn'          => {
         'color' => '##green',
         'line'  => 'AREA'
         },
     'BpsOut'         => {
         'color' => '##blue',
         'line'  => 'LINE2'
         },

     'BusinessDay'    => {
         'color' => '##white',
         'line'  => 'AREA'
         },
     'Evening'        => {
         'color' => '##mintcream',
         'line'  => 'AREA'
         },
     'Night'          => {
         'color' => '##lavender',
         'line'  => 'AREA'
         },

     # Common Definitions
     # Using generic names allows the "generic" value to be
     # changed without editing every instance
     'in'       => {
         'color'   => '##green',
         'line'    => 'AREA'
         },
     'out'      => {
         'color'   => '##blue',
         'line'    => 'LINE2'
         },

     'nearend'       => {
         'color'   => '##green',
         'line'    => 'LINE2'
         },
     'farend'      => {
         'color'   => '##blue',
         'line'    => 'LINE2'
         },

     'maxvalue'       => {
         'color'   => '##darkseagreen',
         'line'    => 'AREA'
         },
     'currvalue'      => {
         'color'   => '##blue',
         'line'    => 'LINE2'
         },

     'totalresource'  => {
         'color'   => '##palegreen',
         'line'    => 'AREA'
         },
     'resourceusage'  => {
         'color'   => '##blue',
         'line'    => 'AREA'
         },
     'resourcepartusage'  => {
         'color'   => '##crimson',
         'line'    => 'AREA'
         },

     # convenient definitions one - ten, colors that
     # "work" in a single graph
     'one'      => {'color'   => '##green'},
     'two'      => {'color'   => '##blue'},
     'three'    => {'color'   => '##red'},
     'four'     => {'color'   => '##gold'},
     'five'     => {'color'   => '##seagreen'},
     'six'      => {'color'   => '##cornflowerblue'},
     'seven'    => {'color'   => '##crimson'},
     'eight'    => {'color'   => '##darkorange'},
     'nine'     => {'color'   => '##darkmagenta'},
     'ten'      => {'color'   => '##orangered'},

     # definitions for combinatorial graphing

     #RED
     'red1'     => {
         'color'  => '##red',
         'line'   => 'AREA',
     },
     'red2'     => {
         'color'  => '##red25',
         'line'   => 'STACK',
     },
     'red3'     => {
         'color'  => '##red50',
         'line'   => 'STACK',
     },
     'red4'     => {
         'color'  => '##red75',
         'line'   => 'STACK',
     },

     #GREEN
     'green1'     => {
         'color'   => '##green',
         'line'    => 'AREA',
     },
     'green2'     => {
         'color'   => '##green25',
         'line'    => 'STACK',
     },
     'green3'     => {
         'color'   => '##green50',
         'line'    => 'STACK',
     },
     'green4'     => {
         'color'   => '##green75',
         'line'    => 'STACK',
     },

     #BLUE
     'blue1'     => {
         'color'   => '##blue',
         'line'    => 'AREA',
     },
     'blue2'     => {
         'color'   => '##blue25',
         'line'    => 'STACK',
     },
     'blue3'     => {
         'color'   => '##blue50',
         'line'    => 'STACK',
     },
     'blue4'     => {
         'color'   => '##blue75',
         'line'    => 'STACK',
     },
     );

# Place for extra RRDtool graph arguments
# Example: ( '--color', 'BACK#D0D0FF', '--color', 'GRID#A0A0FF' );
@Torrus::Renderer::graphExtraArgs = ();

1;
