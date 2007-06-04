# FuzzyOcr plugin, version 2.3b
# Changelog:
#    version 2.0
#	Replaced imagemagick with netpbm
#	Invoke giffix to fix broken gifs before conversion
#	Support png images
#	Analyze the file to detect the format without content-type
#	Added several configuration parameters
#    version 2.1
#       Added scoring for wrong content-type
#       Added scoring for broken gif images
#       Added configuration for helper applications
#       Added autodisable_score feature to disable the OCR engine if the message has already enough points
#    version 2.1b
#       Rule bugfix to avoid warnings
#    version 2.1c
#       Applied patch provided by Howard Kash to fix problems with spamassassin + Mailscanner + FuzzyOcr
#       Removed '-' from jpegtopnm arguments to provide backwards compatibility for older netpbm versions
#       Fixed typo (treshold -> threshold)
#    version 2.2
#       Small bugfix in content-type check for jpeg (jpg was not matching), thanks to Matthias Keller
#       Added more error handling
#       Removed debug files, added logfile instead
#       More messages with verbose = 2
#    version 2.3
#       Multiple scans with different pnm preprocessing and gocr arguments possible
#       Support for interlaced gifs
#       Support for animated gifs
#       Temporary file handling reorganized
#       External wordlist support
#       Personalized wordlist support
#       Spaces are now stripped from wordlist words and OCR results before matching
#       Experimental MD5 Database feature
#    version 2.3b
#       MD5 Database replaced by different feature database
#       Corrupted images are now handled better
#       Added a timeout function to avoid lockups
#       Added threshold overriding on word basis in wordlist
#       Various bugfixes
#
#
# written by Christian Holler decoder_at_own-hero_dot_net

package FuzzyOcr;

use strict;
use warnings;
use Mail::SpamAssassin;
use Mail::SpamAssassin::Util;
use Mail::SpamAssassin::Plugin;

use String::Approx 'adistr';

use FileHandle;
use Fcntl ':flock';

our @ISA = qw (Mail::SpamAssassin::Plugin);

our @err_msges = (
    "Failed to open pipe to external programs with pipe command \"%s\".
Please check that all helper programs are installed and in the correct path.
(Pipe Command \"%s\", Pipe exit code %d (\"%s\"), Temporary file: \"%s\")",
    "Unexpected error in pipe to external programs.
Please check that all helper programs are installed and in the correct path.
(Pipe Command \"%s\", Pipe exit code %d (\"%s\"), Temporary file: \"%s\")",
    "Cannot open \"%s\" to read previously produced data!
(Previously used pipe: \"%s\", error code %d (\"%s\"), Temporary file: \"%s\")",
    "Unexpected error while trying executing gocr with arguments \"%s\".
Make sure the gocr location is specified correctly and the arguments are correct.",
    "Failed to open global wordlist \"%s\" for reading.
Please check that path and permissions are correct."
);

our @words = ();
our $self;
our $pms;

# Default values
our $threshold   = "0.3";
our $base_score  = "4";
our $add_score   = "1";
our $wctypescore = "1.5";
our $cimgscore   = "2.5";
our $cimgscore2   = "5";
our $countreq    = 2;
our $verbose     = 1;
our $timeout     = 10;
our $pre314      = 0;
our $enable_image_hashing  = 0;
our $hashing_learn_scanned = 1;
our ($ts, $th, $tw, $tcn, $tc, $hash_ccnt) = (0.01, 0.01, 0.01, 0.01, 5, 5);
our $giffix      = "/usr/bin/giffix";
our $giftext     = "/usr/bin/giftext";
our $gifasm      = "/usr/bin/gifasm";
our $gifinter    = "/usr/bin/gifinter";
our $giftopnm    = "/usr/bin/giftopnm";
our $jpegtopnm   = "/usr/bin/jpegtopnm";
our $pngtopnm    = "/usr/bin/pngtopnm";
our $pnmfile     = "/usr/bin/pnmfile";
our $ppmhist     = "/usr/bin/ppmhist";
our $convert     = "/usr/bin/convert";
our $identify     = "/usr/bin/identify";
our $gocr        = "/usr/bin/gocr";
our $grep        = "/bin/grep";
our $max_images  = 5;
our $dscore      = 10;
our $logfile     = "/etc/mail/spamassassin/FuzzyOcr.log";
our $pwordlist   = ".spamassassin/fuzzyocr.words";
our $digest_db   = "/etc/mail/spamassassin/FuzzyOcr.hashdb";
our @scansets    = (
    '$gocr -i -',
    '$gocr -l 180 -d 2 -i -'
);

# constructor: register the eval rule
sub new {
    my ( $class, $mailsa ) = @_;
    $class = ref($class) || $class;
    my $self = $class->SUPER::new($mailsa);
    bless( $self, $class );
    $self->register_eval_rule("fuzzyocr_check");
    $self->register_eval_rule("dummy_check");
    return $self;
}

sub parse_config {
    my ( $self, $opts ) = @_;
    if ( $opts->{key} eq "focr_global_wordlist" ) {
        load_global_words( $opts->{value} );
    }
    elsif ( $opts->{key} eq "focr_personal_wordlist" ) {
        $pwordlist = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_threshold" ) {
        $threshold = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_base_score" ) {
        $base_score = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_add_score" ) {
        $add_score = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_corrupt_score" ) {
        $cimgscore = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_corrupt_unfixable_score" ) {
        $cimgscore2 = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_wrongctype_score" ) {
        $wctypescore = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_counts_required" ) {
        $countreq = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_verbose" ) {
        $verbose = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_timeout" ) {
        $timeout = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_scansets" ) {
        parse_scansets( $opts->{value} );
    }
    elsif ( $opts->{key} eq "focr_pre314" ) {
        $pre314 = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_giffix" ) {
        $giffix = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_giftext" ) {
        $giftext = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_gifasm" ) {
        $gifasm = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_gifinter" ) {
        $gifinter = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_giftopnm" ) {
        $giftopnm = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_jpegtopnm" ) {
        $jpegtopnm = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_pngtopnm" ) {
        $pngtopnm = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_ppmhist" ) {
        $ppmhist = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_convert" ) {
        $convert = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_identify" ) {
        $identify = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_gocr" ) {
        $gocr = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_bin_grep" ) {
        $grep = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_gif_max_frames" ) {
        $max_images = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_autodisable_score" ) {
        $dscore = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_enable_image_hashing" ) {
        $enable_image_hashing = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_digest_db" ) {
        $digest_db = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_hashing_learn_scanned" ) {
        $hashing_learn_scanned = $opts->{value};
    }
    elsif ( $opts->{key} eq "focr_logfile" ) {
        $logfile = $opts->{value};
    }
}

sub dummy_check {
    return 0;
}

sub fuzzyocr_check {
    ( $self, $pms ) = @_;
    my $t = Mail::SpamAssassin::Timeout->new({ secs => $timeout });
    $t->run(\&check_fuzzy_ocr);
    if ($t->timed_out()) {
        logfile("FuzzyOcr received timeout after running \"$timeout\" seconds.");
    }
    return 0;
}

sub load_global_words {
    unless ( -r $_[0] ) {
        handle_error( $err_msges[3], ( $_[0] ) );
        return;
    }
    open WORDLIST, "<$_[0]";
    while(<WORDLIST>) {
        chomp($_);
        if (( $_ =~ /^[ \t]*#.*$/ ) or ( $_ =~ /^[^a-zA-Z]$/ )) {
            next;
        }
        $_ =~ s/[ \t]*#.*$//;
        push( @words, $_ );
    }
    close WORDLIST;
    return 1;
}

sub load_personal_words {
    unless ( -e $_[0] ) {
        debuglog("No personal wordlist found, skipping...");
        return;
    }
    unless ( -r $_[0] ) {
        debuglog(
"Unable to read from wordlist \"$_[0]\", please make sure that permissions are correct."
        );
        return;
    }
    open WORDLIST, "<$_[0]";
    while(<WORDLIST>) {
        chomp($_);
        if ( $_ =~ /^[ \t]*#.*$/ ) {
            next;
        }
        $_ =~ s/[ \t]*#.*$//;
        push( @words, $_ );
    }
    close WORDLIST;
}

sub parse_scansets {
    $_[0] =~ s/,[ ]*/,/g;
    @scansets = split( ',', $_[0]);
    debuglog( "Set scansets to values:\n" . join( "\n", @scansets ) );
    return 1;
}

sub max {
    unless ( defined( $_[0] ) and defined( $_[1] ) ) { return 0 }
    unless ( defined( $_[0] ) ) { return $_[1] }
    unless ( defined( $_[1] ) ) { return $_[0] }
    if     ( $_[0] < $_[1] )    { return $_[1] }
    else                        { return $_[0] }
}

sub reorder {
    my $tmp = join( '', @_ );
    return split( '\n', $tmp );
}

sub pipe_io {
    $SIG{PIPE} = 'IGNORE';
    my $pipecmd = shift;
    my $input   = shift;
    my $filecount = 0;
    my $silent = 0;
    my $ignerror = 0;
    my $tmpdir;
    my @stdout  = ();
    my @stderr  = ();
    my ( $tmpfile, $tfilepath ) = Mail::SpamAssassin::Util::secure_tmpfile();
    my ( $errfile, $efilepath ) = Mail::SpamAssassin::Util::secure_tmpfile();
    close($tmpfile);
    close($errfile);
    if ($tmpfile eq $errfile) {
        debuglog("Got same tmpfile twice! Aborting pipe_io() to avoid deadlocking");
        return ( 1, \@stdout, \@stderr );
        unlink($tmpfile);
    }

    if($pipecmd =~ /\$tmpdir/) {
        $tmpdir = Mail::SpamAssassin::Util::secure_tmpdir();
        $pipecmd =~ s/\$tmpdir/$tmpdir/g;
        $filecount = shift;
    } else {
        $silent = shift;
        $ignerror = shift;
    }

    $pipecmd =~ s/\$errfile/$errfile/g;
    my $pipe_pid = open( PIPE_IN, "| $pipecmd 1>$tmpfile 2>>$errfile" );

    unless ($pipe_pid) {
        unless($silent) {
            handle_error( $err_msges[0], ( $pipecmd, $? >> 8, $!, $tmpfile ) );
        }
        unlink($tmpfile);
        unlink($errfile);
        return ( $?, \@stdout, \@stderr );
    }
    flock( PIPE_IN, LOCK_EX );
    print PIPE_IN $input;
    flock( PIPE_IN, LOCK_UN );
    close(PIPE_IN);
    if ($? and not $ignerror) {
        unless($silent) {
            handle_error( $err_msges[1], ( $pipecmd, $? >> 8, $!, $tmpfile ) );
        }
        unlink($tmpfile);
        unlink($errfile);
        return ( $?, \@stdout, \@stderr );
    }
    if ($filecount) {
        my $tsize = 0;
        my $tcount = 0;
        foreach my $nr (0..$filecount-1) {
            my $filesize = 0;
            if ($nr < 10) {
                $filesize = -s "$tmpdir/out0$nr.gif";
            } else {
                $filesize = -s "$tmpdir/out$nr.gif";
            }
            if ($filesize > $tsize) {
                $tsize = $filesize;
                $tcount = $nr;
            }
        }
        if ($tcount < 10) {
            open( PIPE_OUT, "< $tmpdir/out0$tcount.gif" );
        } else {
            open( PIPE_OUT, "< $tmpdir/out$tcount.gif" );
        }
        flock( PIPE_OUT, LOCK_EX );
        @stdout = <PIPE_OUT>;
        flock( PIPE_OUT, LOCK_UN );
        close PIPE_OUT;
        foreach my $nr (0..$filecount) {
            if ($nr < 10) {
                unlink("$tmpdir/out0$nr.gif"); 
            } else {
                unlink("$tmpdir/out$nr.gif");
            }
        }
        rmdir($tmpdir);
        unlink($tmpfile);
        unlink($errfile);
        return ( 0, \@stdout, \@stderr );
    } else {
        unless (open( PIPE_OUT, "< $tmpfile" )
            and open( PIPE_ERR, "< $errfile" ) )
        {
            unless($silent) {
                handle_error( $err_msges[1], ( $pipecmd, $? >> 8, $!, $tmpfile ) );
            }
            unlink($tmpfile);
            unlink($errfile);
            return ( $?, \@stdout, \@stderr );
        }
        flock( PIPE_OUT, LOCK_EX );
        flock( PIPE_ERR, LOCK_EX );
        @stdout = <PIPE_OUT>;
        @stderr = <PIPE_ERR>;
        flock( PIPE_OUT, LOCK_UN );
        flock( PIPE_ERR, LOCK_UN );
        close(PIPE_OUT);
        close(PIPE_ERR);
        unlink($tmpfile);
        unlink($errfile);
        return ( 0, \@stdout, \@stderr );
    }
}

sub handle_error {
    my ( $err_msg, @var_vals ) = @_;
    $err_msg = sprintf( $err_msg, @var_vals );
    logfile($err_msg);
}

sub logfile {
    my $logtext = $_[0];
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    my $time = sprintf(
        "%4d-%02d-%02d %02d:%02d:%02d",
        $year + 1900,
        $mon + 1, $mday, $hour, $min, $sec
    );
    $logtext =~ s/\n/\n                      /g;
    unless ( open LOGFILE, ">> $logfile" ) {
        warn "Can't open $logfile for writing, check permissions";
    }
    flock( LOGFILE, LOCK_EX );
    seek( LOGFILE, 0, 2 );
    print LOGFILE "[$time] $logtext\n";
    flock( LOGFILE, LOCK_UN );
    close LOGFILE;
}

sub check_image_hash_db {
    my $digest = $_[0];
    my ($gpf, @gcf) = split('::', $digest);
    my ($gs, $gh, $gw, $gcn) = split(':', $gpf);

    unless(open(DB, "<$digest_db")) {
        debuglog("No Image Hash database found at \"$digest_db\", or permissions wrong.");
        return 0;
    }
    while(<DB>) {
        chomp($_);
        my ($score, $dpf, @dcf) = split('::', $_);
        my ($ds, $dh, $dw, $dcn) = split(':', $dpf);
        if ((abs($ds - $gs) / $gs) > $ts) { next; }
        if ((abs($dh - $gh) / $gh) > $th) { next; }
        if ((abs($dw - $gw) / $gw) > $tw) { next; }
        if ((abs($dcn - $gcn) / $gcn) > $tcn) { next; }

        my (@dcfs, @gcfs);
        foreach (@dcf) {
            push(@dcfs, split(':', $_));
        }
        foreach (@gcf) {
            push(@gcfs, split(':', $_));
        }
        unless (scalar(@gcfs) eq scalar(@dcfs)) {
            logfile("Error in database format, aborting...");
            return 0;
        }

        foreach (0..scalar(@gcfs) - 1) {
            if (abs($dcfs[$_] - $gcfs[$_]) > $tc) {
                next;
            } 
        }
        return $score;
    }
    return 0;
}

sub add_image_hash_db {
    my $digest = shift;
    my $score = shift;
    my $ret;
    if (-e $digest_db) { 
        $ret = open(DB, ">> $digest_db");
    } else {
        $ret = open(DB, "> $digest_db");
        debuglog("Image Hash Database not found to add hash, creating it...");
    }
    unless ($ret) {
        logfile("Unable to open/create Image Hash database at \"$digest_db\", check permissions.");
        return;
    }
    debuglog("Adding hash \"$digest\" to Image Hash database...");
    flock( DB, LOCK_EX );
    seek( DB, 0, 2 );
    print DB "${score}::${digest}\n";
    flock( DB, LOCK_UN );
    close(DB);
}

sub calc_image_hash {
    my ($rcode, $stdout_ref, $stderr_ref);
    my $picdata = $_[0];
    my ($hash, $h, $w);
    my @ca = ( );
    my $s = length ( $picdata );
    ( $rcode, $stdout_ref, $stderr_ref ) = pipe_io("$identify -", $picdata);
    foreach (@$stdout_ref) {
        if ($_ =~ /([0-9]+)x([0-9]+)/) {
            $h = $1;
            $w = $2;
            last;
        }
    }
    if ($rcode) {
        debuglog("Unable to calculate image hash, skipping...");
        return ($rcode, $hash);
    }
    ( $rcode, $stdout_ref, $stderr_ref ) = pipe_io("$ppmhist -noheader", $picdata);
    if ($rcode) {
        debuglog("Unable to calculate image hash, skipping...");
        return ($rcode, $hash);
    }
    my $cnt = 0;
    my $c = scalar(@$stdout_ref);
    if ($hash_ccnt) {
        foreach (@$stdout_ref) {
            $_ =~ s/ +/ /g;
            my($r, $g, $b, $l, $c) = split(' ', $_);
            push(@ca, "::$r:$g:$b:$l:$c");
            $cnt++;
            if ($cnt ge $hash_ccnt) {
                last;
            }
        }
    }
    $hash = "$s:$h:$w:$c" . join('', @ca);
    return(0, $hash);
}

sub debuglog {
    if ( $verbose > 1 ) {
        logfile("Debug mode: $_[0]");
    }
}

sub wrong_ctype {
    my ( $format, $ctype ) = @_;
    if ($wctypescore) {
        my $debuginfo = "";
        if ( $verbose > 0 ) {
            $debuginfo =
              ("Image has format \"$format\" but content-type is \"$ctype\"");
            debuglog($debuginfo);
        }
        for my $set ( 0 .. 3 ) {
            $pms->{conf}->{scoreset}->[$set]->{"FUZZY_OCR_WRONG_CTYPE"} =
              sprintf( "%0.3f", $wctypescore );
        }
        $pms->_handle_hit( "FUZZY_OCR_WRONG_CTYPE", $wctypescore, "BODY: ",
            $pms->{conf}->{descriptions}->{FUZZY_OCR_WRONG_CTYPE}
              . "\n$debuginfo" );
    }
}

sub corrupt_img {
    my ($unfixable, $err) = @_;
    my $score = 0;
    if ($unfixable) {
        $score = $cimgscore2;
    } else {
        $score = $cimgscore;
    }
    if ($score) {
        my $debuginfo = "";
        if ( $verbose > 0 ) {
            chomp($err);
            $debuginfo = ("Corrupt image: $err");
            debuglog($debuginfo);
        }
        for my $set ( 0 .. 3 ) {
            $pms->{conf}->{scoreset}->[$set]->{"FUZZY_OCR_CORRUPT_IMG"} =
              sprintf( "%0.3f", $score );
        }
        $pms->_handle_hit( "FUZZY_OCR_CORRUPT_IMG", $score, "BODY: ",
            $pms->{conf}->{descriptions}->{FUZZY_OCR_CORRUPT_IMG}
              . "\n$debuginfo" );
    }
}

sub known_img_hash {
    my $digest = shift;
    my $score = shift;
    my $debuginfo = "";
    if ( $verbose > 0 ) {
            $debuginfo = ("Hash \"$digest\" is in the database.");
            debuglog($debuginfo);
    }
    for my $set ( 0 .. 3 ) {
        $pms->{conf}->{scoreset}->[$set]->{"FUZZY_OCR_KNOWN_HASH"} =
        sprintf( "%0.3f", $score );
    }
    $pms->_handle_hit( "FUZZY_OCR_KNOWN_HASH", $score, "BODY: ", $pms->{conf}->{descriptions}->{FUZZY_OCR_KNOWN_HASH} . "\n$debuginfo" );
}

sub check_fuzzy_ocr {
    my @found        = ();
    my $image_type   = 0;
    my $picture_data;
    my @hashes = ();
    my $cnt          = 0;
    my $homedir = (getpwuid($<))[7];

    debuglog("Starting FuzzyOcr...");
    debuglog("Attempting to load personal wordlist...");

    if ($homedir) {
        load_personal_words( $homedir . "/$pwordlist" );
    } elsif (defined($ENV{HOME})) {
        load_personal_words( $ENV{HOME} . "/$pwordlist" );
    } else {
        debuglog("Variable \$ENV{HOME} not defined and getpwuid failed, personal wordlist function not available...");
    }

    foreach my $p ( $pms->{msg}->find_parts(qr/^image\b/i) ) {
        my $cscore = $pms->get_score();
        if ( $cscore > $dscore ) {
            debuglog(
                "Scan canceled, message has already more than $dscore points.");
            return 0;
        }
        my $ctype = $p->{'type'};
        if ( $ctype =~ /image/i ) {
            debuglog("Analyzing file with content-type \"$ctype\"");
            $picture_data = $p->decode();
            my @used_scansets = ();
            my $stdout_ref;
            my $stderr_ref;
            my $rcode = 0;
            my $corrupt = 0;
            my $digest;
            if ( substr($picture_data,0,3) eq "\x47\x49\x46" ) {

                if ( $ctype !~ /gif/i ) {
                    wrong_ctype( "GIF", $ctype );
                }
                $image_type = 1;
                my $interlaced_gif = 0;
                my $image_count = 0;

                ( $rcode, $stdout_ref, $stderr_ref ) =
                  pipe_io( $giftext, $picture_data, 1, 1);

                foreach (@$stdout_ref) {
                    unless ($interlaced_gif) {
                        if ( $_ =~ /Image is Interlaced/i ) {
                            $interlaced_gif = 1;
                        }
                        elsif ( $_ =~ /Image is Non Interlaced/i ) {
                        }
                    }
                    if ( $_ =~ /^Image #/ ) {
                        $image_count++;
                    }
                }


                if ($interlaced_gif or ($image_count gt 1)) {
                    debuglog("Image is interlaced or animated...");
                }
                else {
                    debuglog("Image is single non-interlaced...");
                    ( $rcode, $stdout_ref, $stderr_ref ) = pipe_io( "$giffix", $picture_data, 0, 1);
                    $picture_data = join('', @$stdout_ref);
                }

                foreach (@$stderr_ref) {
                    if ( $_ =~ /GIF-LIB error/i ) {
                        $corrupt = $_;
                        last;
                    }
                }

                if ($corrupt and ($interlaced_gif or ($image_count gt 1))) {
                    debuglog("Skipping corrupted interlaced image...");
                    corrupt_img(1, $corrupt);
                    next;
                } elsif ($corrupt) {
                    unless($picture_data) {
                        debuglog("Uncorrectable corruption detected, skipping non-interlaced image...");
                        corrupt_img(1, $corrupt);
                        next;
                    }
                    debuglog("Image is corrupt, but seems fixable, continuing...");
                    corrupt_img(0, $corrupt);
                }

                if ($image_count gt 1) {
                    debuglog("File contains more than one image...");
                    if ($image_count lt $max_images) {
                        debuglog("Assembling images...");
                        ( $rcode, $stdout_ref, $stderr_ref ) = pipe_io("$convert - +append -", $picture_data);
                        if ($rcode) { next; };
                        $picture_data = join('', @$stdout_ref);
                    } elsif ($pre314 eq 0) {
                        debuglog("Image count exceeds limit, skipping some...");
                        ( $rcode, $stdout_ref, $stderr_ref ) = pipe_io("$gifasm -d \$tmpdir/out", $picture_data, $image_count);
                        if ($rcode) { next; };
                        $picture_data = join('', @$stdout_ref);
                    } else {
                        debuglog("Image count exceeds limit, but your version does not allow the required functions, skipping image...");
                        next;
                    }
                }

                if ($interlaced_gif) {
                    ( $rcode, $stdout_ref, $stderr_ref ) =
                      pipe_io(
                        "$gifinter -s | $giftopnm -", $picture_data );
                    if ($rcode) { next; }
                }
                else {
                    ( $rcode, $stdout_ref, $stderr_ref ) =
                      pipe_io( "$giftopnm -", $picture_data );
                    if ($rcode) { next; }
                }
            }
            elsif ( substr($picture_data,0,2) eq "\xff\xd8" ) {
                if ( $ctype !~ /jpe{0,1}g/i ) {
                    wrong_ctype( "JPEG", $ctype );
                }
                $image_type = 2;
                ( $rcode, $stdout_ref, $stderr_ref ) =
                  pipe_io( "$jpegtopnm", $picture_data );
                if ($rcode) { next; }
            }
            elsif ( substr($picture_data,0,4) eq "\x89\x50\x4e\x47" ) {
                if ( $ctype !~ /png/i ) {
                    wrong_ctype( "PNG", $ctype );
                }
                $image_type = 3;
                ( $rcode, $stdout_ref, $stderr_ref ) =
                  pipe_io( "$pngtopnm -", $picture_data );
                if ($rcode) { next; }
            }
            else {
                $image_type = 0;
                debuglog(
"Image type not recognized, unknown format. Skipping this image..."
                );
                next;
            }

            debuglog("Recognized file type: $image_type");

            my @pnmdata = @$stdout_ref;
            if($enable_image_hashing) {
                debuglog("Calculating the image hash...");
                ($rcode, $digest) = calc_image_hash(join('', @pnmdata));
                if ($rcode) {
                    debuglog("Error calculating the image hash, skipping hash check...");
                } else {
                    if (my $score = check_image_hash_db($digest)) {
                        debuglog("Image found in hash database, message is spam...");
                        debuglog("Scoring with known old score and ending...");
                        known_img_hash($digest, $score);
                        return 0;
                    }
                }
                debuglog("Hash not yet known to the database, saving for later db storage...");
                push(@hashes, $digest);
            } else {
                debuglog("Image hashing disabled in configuration, skipping...");
            }
            my @ocr_results = ();

            foreach my $scanset (@scansets) {
                $scanset =~ s/\$gocr/$gocr/;
                ( $rcode, $stdout_ref, $stderr_ref ) =
                  pipe_io( "$scanset", join( '', @pnmdata ), 1);

                if ($rcode) {
                    debuglog(join( '', @$stderr_ref ));
                    debuglog(
"Skipping scanset \"$scanset\" because of errors, trying next..."
                    );
                    next;
                }

                my @ocrdata = @$stdout_ref;
                push( @ocr_results, [@ocrdata] );
                push( @used_scansets, $scanset );
            }
            foreach my $w (@words) {
                my $wthreshold;
                if ($w =~ /^(.*?)::(0(\.\d+){0,1})/) {
                    ($w, $wthreshold) = ($1, $2);
                } else {
                    $wthreshold = $threshold;
                }
                $w =~ s/[^a-zA-Z]//g;
                $w = lc $w;
                my $wcnt = 0;
                my $gcnt = 0;
                foreach my $ocr_set (@ocr_results) {
                    my $cwcnt = 0;
                    foreach (@$ocr_set) {
                        tr/!;|081/iiioal/;
                        s/[^a-zA-Z]//g;
                        $_ = lc;
                        my $matched = adistr( $w, $_ );
                        if ( abs($matched) < $wthreshold ) {
                            $cwcnt++;
                            debuglog(
"Found word \"$w\" in line\n \"$_\" \n with fuzz of "
                                  . abs($matched)
                                  . " scanned with scanset $used_scansets[$gcnt]"
                            );
                        }
                    }
                    $wcnt = max( $wcnt, $cwcnt );
                    $gcnt++;
                }
                $cnt += $wcnt;
                if ( ( $verbose > 0 ) and ($wcnt) ) {
                    push( @found, "\"$w\" in $wcnt lines" );
                }
            }
        }
    }
    if ( $cnt >= $countreq ) {
        my $score = ( $base_score + ( $cnt - $countreq ) * $add_score );
        if($enable_image_hashing and $hashing_learn_scanned) {
            debuglog("Message is spam (score $score), storing all image hashes in database...");
            foreach (@hashes) {
                add_image_hash_db($_, $score);
            }
        } else {
            debuglog("Message is spam (score $score)...");
        }
        my $debuginfo = "";
        if ( $verbose > 0 ) {
            $debuginfo =
              (     "Words found:\n"
                  . join( "\n", @found )
                  . "\n($cnt word occurrences found)" );
            debuglog($debuginfo);
        }
        for my $set ( 0 .. 3 ) {
            $pms->{conf}->{scoreset}->[$set]->{"FUZZY_OCR"} =
              sprintf( "%0.3f", $score );
        }
        $pms->_handle_hit( "FUZZY_OCR", $score, "BODY: ",
            $pms->{conf}->{descriptions}->{FUZZY_OCR} . "\n$debuginfo" );
    }
    debuglog("FuzzyOcr ending successfully...");
    return 0;
}

1;
