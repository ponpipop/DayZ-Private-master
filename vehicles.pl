#!/usr/bin/perl -w
# Author: Guru Abdul
# Script generating vehicles for DayZ Arma mod

use POSIX;
use DBI;
use DBD::mysql;
use Getopt::Long;

print "INFO: Started vehicle insertion.\n";

my %args = ();

GetOptions(
	\%args,
	'instance|index|i=s',
	'hostname|host|dbhost|h=s',
	'username|user|dbuser|u=s',
	'password|pass|dbpass|p=s',
	'database|dbname|d=s',
	'port|dbport=s',
	'help'
);

my %db = (
	'host' => $args{'hostname'} ? $args{'hostname'} : 'localhost',
	'instance' => $args{'instance'} ? $args{'instance'} : '1',
	'limit' => $args{'limit'} ? $args{'limit'} : '500',
	'user' => $args{'username'} ? $args{'username'} : 'dayz',
	'pass' => $args{'password'} ? $args{'password'} : 'dayz',
	'name' => $args{'database'} ? $args{'database'} : 'dayz',
	'port' => $args{'port'} ? $args{'port'} : '3306'
);

my $dsn = "dbi:mysql:$db{'name'}:$db{'host'}:$db{'port'}";
print "Generating vehicles for instance: ".$db{'instance'}." , with user: ".$db{'user'}."\n";
my $dbh = DBI->connect($dsn, $db{'user'}, $db{'pass'}) or die "Couldn't connect to db: ".DBI->errstr;
my $sth = $dbh->prepare('DELETE FROM objects WHERE damage>=0.95 OR (lastupdate<DATE_SUB(NOW(),INTERVAL 5 DAY) AND NOT otype="TentStorage");') or die;
$sth->execute() or die "Couldn't execute statement" . $sth->errstr;#Clean dead vehicles
my $numGenerated=0;#counter for the number of generated vehicles
my @vehicles = ("UAZ%","ATV%","Skoda%","TT650%","Old_bike%","UH1H%","hilux%","Ikarus%","Tractor","S1203%","V3S_Civ","UralCivil","car%","%boat%","PBX","Volha%","SUV%");
my @vehicleLimits = (4,3,3,3,10,3,3,3,3,4,1,1,2,4,1,3,1);
my @chances = (0.65,0.7,0.65,0.7,0.95,0.25,0.55,0.55,0.75,0.55,0.55,0.55,0.55,0.75,0.55,0.55,0.45);
my $n=0;
my $do=0;
$sth = $dbh->prepare("SELECT COUNT(*) FROM objects WHERE instance=? AND otype NOT IN ('TentStorage','Hedgehog_DZ','Wire_cat1')") or die;
$sth->execute($db{'instance'}) or die;
my $globalVehicleCount;
my @d =$sth->fetchrow_array();
$globalVehicleCount= $d[0];
my $first=0;
$sth = $dbh->prepare('SELECT COUNT(*) FROM objects WHERE otype like ? AND instance=?') or die;
my $query = "INSERT INTO objects (uid,pos,health,damage,otype,instance) VALUES ";
for (my $i=0;$i<scalar @vehicles;$i++)
{
	my $vehicle = $vehicles[$i];
	$sth->execute($vehicle,$db{'instance'}) or die;
	my @data = $sth->fetchrow_array();
	my $vehicleCount = $data[0];
	my $spawnCount = 0;
	my $chance = $chances[$i];
	my $chanceFactor=1.5;
	my $random = rand();
	#print "Chance: ".$chance." Random: ".$random."\n";
	my $limit = $vehicleLimits[$i]-$vehicleCount;
	while($chance>$random && $spawnCount<$limit)
	{
		$chance /= $chanceFactor;
		$chanceFactor += 0.14;
		$spawnCount++;
		#print "ModChance: ".$chance."\n";
	}
	print "INFO: Generating ".$spawnCount." vehicles of type: ".$vehicle."\n";
	my $sts = $dbh->prepare('SELECT * FROM spawns WHERE otype like ? AND NOT uuid IN (SELECT uid FROM objects WHERE instance = ?) ORDER BY RAND() LIMIT ?') or die;
	$sts->execute($vehicle,$db{'instance'},$spawnCount) or die;
	while ((@data = $sts->fetchrow_array())&&$globalVehicleCount+$n<$db{'limit'})
	{
		print "Generating vehicle parts damage!\n";
		my $health="";
		my @parts;
		my $damage = rand(0.75);
		my @restricted;
		$damage = $damage<= 0.05 ? 0 : $damage;
		
		if($vehicle eq "Old_bike%"){}
		elsif($vehicle eq "TT650%"||$vehicle eq "%boat%"||$vehicle eq "PBX")
		{
			@parts = ('["motor",1]');
			$health = genDamage(@parts);
		}
		elsif($vehicle eq "UH1H%")
		{
			@parts = ('["motor",1]','["elektronika",1]','["mala vrtule",1]','["velka vrtule",1]');
			$damage=0;
			$health = genDamage(@parts);
		}
		else
		{
			@parts = ('["palivo",1]','["motor",1]','["karoserie",1]','["wheel_1_1_steering",1]','["wheel_1_2_steering",1]','["wheel_2_1_steering",1]','["wheel_2_2_steering",1]');
			$health = genDamage(@parts);
		}
		print "INFO: Damaged parts are ".$health."\n";
		#add
		#uid,pos,health,damage,otype,instance
		if($first==0)
		{
			$first=1;
			$query.="($data[3],'$data[1]','[$health]',$damage,'$data[2]',$db{'instance'})";
		}
		else
		{
			$query.=",($data[3],'$data[1]','[$health]',$damage,'$data[2]',$db{'instance'})";
		}
		$do=1;
		$n++;
	}
	
}
#send
$sth = $dbh->prepare($query);
if($do==1)
{
	print $query."\n";
	$sth->execute() or die "Insert query failed";
	print "INFO: Spawed $n randomly damaged vehicles!";
}
else
{
	print "ERROR: Reached maximum vehicle limit for these types of vehicles! Not spawning any vehicles...";
}
sub genDamage
{
	
	my $h="";
	my $damParts=0;
	my $damCount=0;
	my $random = rand();
	my $chance = 0.99;
	my $chanceFactor = 1.15;
	my @parts = @_;
	my @restricted;
	#print "Chance: ".$chance." Random: ".$random."\n";
	while($chance>$random && $damParts<scalar @parts)
	{
		$chance /= $chanceFactor;
		$chanceFactor += 0.15;
		$damParts++;
		#print "ModChance: ".$chance."\n";
	}
	$damCount=0;
	while($damParts>$damCount)
	{
		$random = floor(rand(scalar @parts));
		my %restr = map {$_ => 1} @restricted;
		if(!exists($restr{$random}))
		{
			push (@restricted,$random);
			if($h eq ""){$h = $parts[$random];}
			else{$h .= ",".$parts[$random];}
			$damCount++;
		}
	}
	return $h;
}
