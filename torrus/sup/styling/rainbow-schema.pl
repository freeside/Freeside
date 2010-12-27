# Example of alternate style
# rougly the traditional colors in a rainbow.
#  Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>
#
# This file should be referenced using the
# $Torrus::Renderer::stylingProfileOverlay option:
#   $Torrus::Renderer::stylingProfileOverlay = "rainbow-schema";

$Torrus::Renderer::graphStyles{'one'}{'color'} = '##darkred';
$Torrus::Renderer::graphStyles{'two'}{'color'} = '##red';
$Torrus::Renderer::graphStyles{'three'}{'color'} = '##yellow';
$Torrus::Renderer::graphStyles{'four'}{'color'} = '##deeppink';
$Torrus::Renderer::graphStyles{'five'}{'color'} = '##forestgreen';
$Torrus::Renderer::graphStyles{'six'}{'color'} = '##orange';
$Torrus::Renderer::graphStyles{'seven'}{'color'} = '##indigo';
$Torrus::Renderer::graphStyles{'eight'}{'color'} = '##blueviolet';
$Torrus::Renderer::graphStyles{'nine'}{'color'} = '##blue';
$Torrus::Renderer::graphStyles{'ten'}{'color'} = '##deepskyblue';

# slightly off white background with gold grid lines
push( @Torrus::Renderer::graphExtraArgs,
      '--color=CANVAS#DCDCDC',  #light grey
      '--color=BACK#808080',    # darker grey
      '--color=GRID#FFD700' );  # gold

1;
