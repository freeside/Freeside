
use threads;

$| = 1;

print "The child thread must keep ticking while the main thread sleeps\n";
print "If it's not so, then we have a compatibility problem\n";



my $thrChild = threads->create( \&child );
$thrChild->detach();

print "P> Launched the child thread. Now I sleep 20 seconds\n";
sleep(20);
print "P> Parent woke up. Was there ticking inbetween?\n";

exit 0;



sub child
{
    print "C> Child thread started. I will print 10 lines, one per second\n";

    foreach my $i (1..10)
    {
        print("C> Child tick " . $i . "\n");
        sleep(1);
    }
}

        
            
        
    

