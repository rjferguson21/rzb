#!/usr/bin/perl

use LWP::UserAgent;
use Data::Dumper;
use Getopt::Long;
use Number::Format qw(:subs);
use IMDB::Film;
use YAML qw(LoadFile);

sub download;
sub search;
sub changeCategory;

use constant DEBUG => 0; 

# User Profile
my $apikey    = '';
my $username = '';
my $downloadDirectory = '/home/rob/';

# Defaults
my $searchfor = "ubuntu";
my $category  = "21";

# Configuration
my $imdbFetch = 0;
my $pageSize  = 20;

my $config = LoadFile('rzb_config.yaml');

$apikey = $config->{api_key};
$username = $config->{username};

my %categories = (
  EVERYTHING => '0',

  MOVIES_ALL       => 'movies-all',
  MOVIES_DVD       => '1',
  MOVIES_DIVX_XVID => '2',
  MOVIES_HD_X264   => '42',
  MOVIES_HD_BLURAY => '50',
  MOVIES_WMV_HD    => '48',
  MOVIES_SVCD_VCD  => '3',
  MOVIES_OTHER     => '4',

  TV_ALL       => 'tv-all',
  TV_DVD       => '5',
  TV_DIVX_XVID => '6',
  TV_HD        => '41',
  TV_SPORT_ENT => '7',
  TV_OTHER     => '8',

  DOCUMENTARIES_ALL => 'docu-all',
  DOCUMENTARIES_STD => '9',
  DOCUMENTARIES_HD  => '53',

  GAMES_ALL       => 'games-all',
  GAMES_PC        => '10',
  GAMES_PS2       => '11',
  GAMES_PS3       => '43',
  GAMES_PSP       => '12',
  GAMES_XBOX      => '13',
  GAMES_XBOX360   => '14',
  GAMES_PS1       => '15',
  GAMES_DREAMCAST => '16',
  GAMES_WII       => '44',
  GAMES_WII_VC    => '51',
  GAMES_DS        => '45',
  GAMES_GAMECUBE  => '46',
  GAMES_OTHER     => '17',

  APPS_ALL          => 'apps-all',
  APPS_PC           => '18',
  APPS_MAC          => '19',
  APPS_PORTABLE     => '51',
  APPS_LINUX        => '20',
  APPS_OTHER        => '21',
  MUSIC_ALL         => 'music-all',
  MUSIC_MP3_ALBUMS  => '22',
  MUSIC_MP3_SINGLES => '47',
  MUSIC_LOSSLESS    => '23',

  MUSIC_DVD   => '24',
  MUSIC_VIDEO => '25',
  MUSIC_OTHER => '27',

  ANIME_ALL => '28',

  OTHER_ALL              => 'other-all',
  OTHER_AUDIO_BOOKS      => '49',
  OTHER_EMULATION        => '33',
  OTHER_PPC_PDA          => '34',
  OTHER_RADIO            => '26',
  OTHER_EBOOKS           => '36',
  OTHER_IMAGES           => '37',
  OTHER_MOBILE_PHONE     => '38',
  OTHER_EXTRA_PARS_FILLS => '39',
  OTHER_OTHER            => '40',
);


my @nzbs = ();

while () {
  print "rzb# ";

  my $re = <>;
  chomp($re);

  if ( $re =~ /^search (.+)/ ) {
    $searchfor = $1;
    search($searchfor);
  }
  elsif ( $re =~ /^download (\d+)/ ) {
    my $downloadid = $1;
    download( $1, "temp.nzb" );
  }
  elsif ( $re =~ /^info (.*)/ ) {
    my $downloadid = $1;
    getinfo($1);
  }
  elsif ( $re =~ /^category (.*)/ ) {
    my $newcategory = $1;
    changeCategory($newcategory);
  }
  else {
    print "search <search criteria>\n";
    print "download <nzb number>\n";
    print "info <nzb number>\n";
    print "category <category namer> | list\n";
  }

}

sub search 
{
  my $searchfor = shift;
  $result = GetOptions( "search=s" => \$searchfor );    # numeric

my $ua = LWP::UserAgent->new;
$ua->agent("MyApp/0.1 ");

# Create a request
my $req =
HTTP::Request->new( GET =>
  "http://api.nzbmatrix.com/v1.1/search.php?search=$searchfor&catid=$category&num=$pageSize&username=$username&apikey=$apikey"
);
$req->content_type('application/x-www-form-urlencoded');

print $req->as_string();

# Pass request to the user agent and get a response back
my $res = $ua->request($req);

# Check the outcome of the response
if ( $res->is_success ) 
{
  #print $res->content;
}
else 
{
  print $res->status_line, "\n";
}

my @output = ();
@nzbs = ();

@output = split( /^/, $res->content );

my $nzbhash = {};

foreach (@output) 
{
  my $line = $_;

  if ( $line =~ m/^\|$/ ) 
  {
    push( @nzbs, $nzbhash );
    $nzbhash = {};

  }
  else 
  {
    my @keyval = split( /:/, $line, 2 );
    chomp( $keyval[1] );
    chop( $keyval[1] );
    $nzbhash->{ $keyval[0] } = $keyval[1];
  }
}

for my $i ( 0 .. $#nzbs ) 
{

  print "\n";
  print "( #$i ) ";
  print $nzbs[$i]->{NZBNAME};

  #'WEBLINK' => 'http://imdb.com/title/tt0080684/'

  my $imdbid;

  if ( $imdbFetch && ( $nzbs[$i]->{WEBLINK} =~ m/.*tt(\d+)\// ) ) 
  {
    $imdbid = $1;

    print "\n";
    my $imdb = new IMDB::Film( crit => $imdbid );

    my $rating = $imdb->rating();

    print "imdb title: ", $imdb->title(), "\n";
    print "imdb rating: ", $rating, "\n";
    $nzbs[$i]->{IMDBID} = $imdbid;
  }

  print " ( ", format_bytes( $nzbs[$i]->{SIZE}, precision => '1' ), " )\n";
  print "$nzbs[$i]->{USENET_DATE}";
  print "\n\n";
}
}

sub getinfo {
  my $nzbNumber = shift;
  print Dumper( $nzbs[$nzbNumber] );
  my $imdbid    = $nzbs[$nzbNumber]->{IMDBID};
  print $imdbid;    

  my $imdb = new IMDB::Film( crit => $imdbid );

  print "imdb storyline: ", $imdb->storyline(), "\n";
}

sub changeCategory 
{
  $newCategory = shift;
  if ( lc($newCategory) =~ m/list/ ) 
  {
    foreach my $key ( sort ( keys %categories ) ) 
    {
      printf( "%-30s %-15s\n", $key, $categories{$key} );
    }
  }
  else 
  {
    if( exists( $categories{ uc($newCategory) } ) )
    {
      $category = $categories{uc($newCategory)};
      print "category is now $category\n";
    }
    else
    {
      print "category does not exist\n";
      my $ucKey = uc($newCategory);
      print "upper case key $ucKey\n" if DEBUG;
      print "non-existent category $categories{$ucKey}\n" if DEBUG;
      print $ucKey . "\n" if DEBUG;
    }


  }

}

sub download 
{
  my $nzbNumber = shift;
  my $nzbname   = shift;

  my $nzbid = $nzbs[$nzbNumber]->{NZBID};
  $nzbname = $nzbs[$nzbNumber]->{NZBNAME};

  my $url = "http://api.nzbmatrix.com/v1.1/download.php?id=$nzbid&username=$username&apikey=$apikey";

  my $ua = LWP::UserAgent->new;
  $ua->agent("MyApp/0.1 ");

  # Create a request
  my $req = HTTP::Request->new( GET => $url );
  $req->content_type('application/x-www-form-urlencoded');

  print $req->as_string();

  # Pass request to the user agent and get a response back
  my $res = $ua->request($req);

  # Check the outcome of the response
  if ( $res->is_success ) 
  {

    #print $res->content;
    print "downloading nzb\n";
    open FH, ">$downloadDirectory/$nzbname.nzb";
    print FH $res->content;
    close(FH);
  }
  else 
  {
    print $res->status_line, "\n";
  }

  print "done downloading nzb: $nzbname\n";
}

