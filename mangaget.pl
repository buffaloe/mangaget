#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use File::Path qw/make_path/;

my ($url, $start, $end, $verbose);


sub get_page {
    my $url = shift;
    open PAGE, '-|', "wget -O - '$url' -q"
        or die "can't wget url: $!";
    my @lines = <PAGE>;
    close PAGE;
    chomp @lines;
    return @lines;
}

sub download_image {
    my ($url, $manga_name, $volume, $chapter) = @_;

    $url =~ /\/([^\/]+)$/;
    my $basename = $1;

    my $dir = "$manga_name/v$volume/c$chapter";
    make_path($dir);

    if (-e "$dir/$basename") {
        print "Image already downloaded, skipping...\n" if $verbose;
    } else {
        print "\n" if $verbose;
        my $cmd = "wget -O '$dir/$basename' '$url'";
        $cmd .= " -q" unless $verbose;
        print "[$cmd]\n" if $verbose;
        my $res = system $cmd;

        if ($res != 0) {
            unlink "$dir/$basename" if (-e "$dir/$basename");
            die "wget of image failed (status = $res)"
        }
        print "\n" if $verbose;
    }
}

GetOptions(
    "verbose|v" => \$verbose,
    "url=s"   => \$url,
    "start=s" => \$start,
    "end=s"   => \$end) or
        die "Something went wrong with GetOptions";

if (!defined($url) || !defined($start) || !defined($end)) {
    die "Please specify base manga URL and chapter range to download";
}

if ($url !~ /^http:\/\/(www\.)?mangafox.com\/manga\/([^\/]+)(\/)?/) {
    die "Only support mangafox.com at the moment";
}

my $manga_name = $2;
my @chapters;
print "Downloading manga '$manga_name', chapters $start to $end.\n";

foreach (get_page($url.'?no_warning=1')) {
    if (/^\s*<a\s+href="\/manga\/$manga_name\/v(\d+)\/c(\d+)\/"\s+class="chico">\s*$/) {
        my ($volume,$chapter) = ($1,$2);
        if ($start <= $chapter && $chapter <= $end) {
            push @chapters, "http://www.mangafox.com/manga/$manga_name/v$volume/c$chapter";
        }
    }
}

@chapters = sort @chapters;
foreach my $chapter (@chapters) {
    print $chapter, "\n";
    $chapter =~ /\/v(\d+)\/c(\d+)$/ or die "Regex should have matched URL...";
    my ($volno, $chapno) = ($1, $2);

    print "*** Volume $volno, Chapter $chapno ***\nPages ";

    my @lines;
    my $pageno = 1;
    while (@lines = get_page("$chapter/$pageno.html")) {
        my $found = 0;
        foreach (@lines) {
            if (/<img src="(.*?)" width=".*?" id="image"/) {
                download_image($1, $manga_name, $volno, $chapno);
                $found = 1;
                last;
            }
        }
        last if !$found;
        print "$pageno, ";
        $pageno ++;
    }
    print "\n\n";
}
