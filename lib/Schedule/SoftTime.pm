=head1 NAME

Schedule::SoftTime - Scheduling functions (designed) for link checking

=head1 SYNOPSIS

       $sched = new Schedule::SoftTime, sched.db;
       $sched->schedule("last", 400);
       $sched->schedule("first", 200);
       $sched->next();
	     "first"

=head1 DESCRIPTION

This is a class to implement an `I'll get round to you when I can be
bothered' scheduler.  It's based on the queue system in our banks
shops and some doctors I've been to.  You turn up any time you want,
but then you have to wait till everyone else who was there before you
has been dealt with.  The idea is to let the items being scheduled do
so at any free time they wish and then worry about resource
requirements later.  If we can't handle some items when they were
scheduled, they just queue until they can be handled.

These routines were designed for the LinkController robot to use, but
actually they are fairly general routines.  The objects being
scheduled have to have.

	  $OBJECT->time_want_test() ; says when the object would like to
				      be tested
	  $OBJECT->time_scheduled() ; stores and returns the time we
				      decide to schedule the object.




The time_scheduled should not be changed by the object (though I
suppose it could keep one value for each link tester.. somehow?)

The functions provided are

    first_item() - give out the next object which should be checked if
    any (first on the queue)
    next_item() - give out the item after the last we gave out
    schedule(time, object) - schedule an object for testing
    unschedule(object) - unschedule an object

potentially you would want

   schedule_priority - put an object in as soon as reasonable
      (simulates an old person coming in and asking to skip to the front
       of the queue)

We guarantee that objects get checked eventually by never allowing an
object to be scheduled before the time now.

We allow prioritisation by putting identifiers in at whatever time they ask
for.

The time an object is scheduled for represents the first time it could
be scheduled for checking.  How close to reality it is depends on how
bad the backlog is.

If you have sufficient resources, you should be able to clear the
backlog no matter what and the schedule will match reality.

If you are rude (always schedule identifiers for immediate checking) or
underresourced this will degenerate to a queue in which the back end
is a little disorganised (but in a helpful friendly kind of way).

If there is some level of lookahead into the queue (for example so
that you can check identifiers on other sites whilst waiting for the longer
robot exclusion period on one site), you should make sure that you
don't make the situation of the first identifier worse.

=head1 METHODS

=head2 new Schedule::SoftTime filename

The new function sets up a schedule object using the file given as an
argument for it's storage.

=cut

package Schedule::SoftTime;
$VERSION=0.011;

use Fcntl;
use DB_File;

#FIXME.  we should accept different options here in the new so that it
#is possible to fail to create a schedule database.

sub new ($$) {
  my $class=shift;
  my $filename=shift;
  my $self={};
  my %hash;
  bless $self, $class;
  $self->{"schedule"} = tie %hash,  DB_File, $filename, O_CREAT|O_RDWR,
    0666, $DB_BTREE
    or die "couldn't open $filename: " . $!;
  $self->{"sched_hash"} = \%hash;
  return $self;
}

#$::verbose=1;


=head2 schedule

Schedule::SoftTime takes a identifier, and schedules it as soon after the time
given as possible.  We never schedule backwards in time.. That could
be implemented by unscheduling then trying again with an earlier
time..

=cut

sub schedule {
  my $self=shift;
  my $time=shift;
  my $identifier=shift;
  my $hash=$self->{"sched_hash"};

  die "need to know when to schedule" unless defined $time;
  die "need an identifier to schedule" unless defined $identifier;
  print STDERR "trying to schedule $identifier at $time\n";
  while ( defined $self->{"sched_hash"}->{$time} ){
    $time++;
    #in otherwords there is always a second between different
    #schedulings.. bit arbitrary huh?  Well so is the resolution of
    #UNIX time.  Don't blame me, just use a different kind of time.
  }
  $hash->{$time}=$identifier;
  print STDERR $hash->{$time},
    " scheduled at $time (" . localtime($time) . ")\n";
  return $time;
}

=head2 unschedule

Remove whatever identifier is in a schedule slot using the schedule time.

=cut

sub unschedule {
  my $self=shift;
  my $time=shift;
  my $hash=$self->{"sched_hash"};
  my $identifier=$hash->{$time};
  print STDERR "using time $time (" . localtime($time) .
    ") to unschedule $identifier\n";
  delete $hash->{$time};
  return $identifier;
}

=head2 first_item

Give out the first item that should be scheduled (probably overdue)

=cut

sub first_item {
  my $self=shift;
  my $key=0; #everything should be later than time 0
  my $value=0;
  $self->{"schedule"}->seq($key, $value, R_CURSOR);
  $self->{"last_key"}=$key;
  print STDERR "Schedule first key: " . $key . " value: " . $value . "\n";
  return $key, $value;
}


=head2 next_item

Give out the first item that should be scheduled (probably overdue)

=cut

sub next_item {
  my $self=shift;
  my $key;
  my $value;
  my $stat=0;
  $key=$self->{"last_key"};
  $key=0 unless defined $key;
  $key++;
  $stat=$self->{"schedule"}->seq( $key, $value, R_CURSOR);
  unless ($stat==0) {
    $self->{"last_key"}=$undef;
    print STDERR "Schedule didn't return a key\n";
    return undef;
  }
  $self->{"last_key"}=$key;
  print STDERR "Schedule next key: " . $key . " value: " . $value . "\n";
  return $key, $value;
}

42; #bunny rabbits.  Requires this.





