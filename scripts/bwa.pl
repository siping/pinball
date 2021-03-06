#!/usr/bin/perl
use strict;
use Getopt::Long;

my ($databasefile,$readsfile,$onlyindex,$tmpdir,$threads,$tag,$debug,$onlyhits);
$tag = time;
my $bwa_executable      = "/homes/avilella/pinball/bwa/bwa";
my $samtools_executable = "/homes/avilella/pinball/samtools/samtools";
my $indexmethod = '';
my $method = 'aln';
my $tmpdir = '/tmp';
my $z_option = 1000;
my $onlyhits_option = '';

GetOptions
  (
   'ref|db|input|databasefile:s'               => \$databasefile,
   'tmpdir:s'                                  => \$tmpdir,
   'r|reads|readsfile:s'                       => \$readsfile,
   't|tag:s'                                   => \$tag,
   'threads:s'                                 => \$threads,
   'd|debug:s'                                 => \$debug,
   'onlyindex|indexonly|only_index|index_only' => \$onlyindex,
   'onlyhits|hitsonly'                         => \$onlyhits,
   'indexmethod:s'                             => \$indexmethod,
   'method:s'                                  => \$method,
   'z_option:s'                                => \$z_option,
   'bwa_exe|bwa_executable:s'                  => \$bwa_executable,
   'samtools_exe|samtools_executable:s'        => \$samtools_executable,
  );

my $self = bless {};
my $tmp_dir = $self->worker_process_temp_directory;
$onlyhits_option = '-F 0x4' if (defined $onlyhits);

my $cmd;
# bwa index
my $indexmethod = "-a $indexmethod" unless ('' eq $indexmethod);
$cmd = "$bwa_executable index $indexmethod $databasefile";
print STDERR "# $cmd\n" if ($debug);
if (1 != $onlyindex && ((-e "$databasefile.bwt" && !-z "$databasefile.bwt") || (-e "$databasefile.pac" && !-z "$databasefile.pac"))) {
  print STDERR "$databasefile already indexed\n";
} else {
  unless(system("$cmd") == 0) {    print("$cmd\n");    throw("error running bwa index: $!\n");  }
}

exit 0 if ($onlyindex);

if ($method eq 'bwasw' && defined $z_option) {
  $z_option = "-z $z_option";
}

# bwa aln
my $threads_option == ''; $threads_option = "-t $threads" if (defined $threads);
if ($method eq 'bwasw') {
  $cmd = "$bwa_executable bwasw $z_option $threads_option $databasefile $readsfile > $tmp_dir/$$.sam";
  print STDERR "$cmd\n" if ($debug);
  unless(system("$cmd") == 0) {    print("$cmd\n");    throw("error running bwa aln: $!\n");  }
} else {
  $cmd = "$bwa_executable aln $threads_option $databasefile $readsfile > $tmp_dir/$$.sai";
  print STDERR "$cmd\n" if ($debug);
  unless(system("$cmd") == 0) {    print("$cmd\n");    throw("error running bwa aln: $!\n");  }

  # bwa samse
  $cmd = "$bwa_executable samse $databasefile $tmp_dir/$$.sai $readsfile > $tmp_dir/$$.sam";
  print STDERR "$cmd\n" if ($debug);
  unless(system("$cmd") == 0) {    print("$cmd\n");    throw("error running bwa samse: $!\n");  }
}

# samtools view
$cmd = "$samtools_executable view $onlyhits_option -S -b -o $tmp_dir/$$.bam $tmp_dir/$$.sam";
print STDERR "$cmd\n" if ($debug);
unless(system("$cmd") == 0) {    print("$cmd\n");    throw("error running samtools view: $!\n");  }

# samtools sort
$cmd = "$samtools_executable sort $tmp_dir/$$.bam $tag";
print STDERR "$cmd\n" if ($debug);
unless(system("$cmd") == 0) {    print("$cmd\n");    throw("error running samtools sort: $!\n");  }

# samtools index
$cmd = "$samtools_executable index $tag.bam";
print STDERR "$cmd\n" if ($debug);
unless(system("$cmd") == 0) {    print("$cmd\n");    throw("error running samtools index: $!\n");  }

print "$tag.bam\n";
print "$tag.bam.bai\n";

if ($debug) {
  $cmd = "$samtools_executable view $tag.bam" if ($debug);
  print STDERR "$cmd\n" if ($debug);
  unless(system("$cmd") == 0) {    print("$cmd\n");    throw("error running samtools view: $!\n");  }
}

$self->cleanup_worker_process_temp_directory;

########################################
#### METHODS
########################################

sub DESTROY {
  my $self = shift;
  $self->cleanup_worker_process_temp_directory;
}

sub worker_process_temp_directory {
  my $self = shift;
  
  unless(defined($self->{'_tmp_dir'}) and (-e $self->{'_tmp_dir'})) {
    #create temp directory to hold fasta databases
    $self->{'_tmp_dir'} = $tmpdir . "/worker.$$/";
    mkdir($self->{'_tmp_dir'}, 0777);
    throw("unable to create ".$self->{'_tmp_dir'}) unless(-e $self->{'_tmp_dir'});
  }
  return $self->{'_tmp_dir'};
}


sub cleanup_worker_process_temp_directory {
  my $self = shift;
  if($self->{'_tmp_dir'}) {
    my $cmd = "rm -r ". $self->{'_tmp_dir'};
    system($cmd) if (-e $self->{'_tmp_dir'});
  }
}
