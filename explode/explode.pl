
# TODO: extend this to handle .tar, .tar.gz, .tgz
@ARCHIVE_EXTENSION = (
    'zip',
    'jar',
    'ear',
    'war'
    );
foreach my $e (@ARCHIVE_EXTENSION) {
    $e =~ tr/A-Z/a-z/;
    $ARCHIVE_EXTENSION{$e} = 1;
}
$EXPLODED_DIR=".exploded_vgIxfkPjEd+O1gATcpnC1A";

$LOG_PREFIX = 0;
$LOG_VERBOSE = 0;

$CLEANUP = 0;

sub logmsg {
    my ($level, $msg) = @_;

    my ($prefix) = " " x $LOG_PREFIX;
    if ($LOG_VERBOSE > 0 || $level ne "INFO") {
	print STDERR "[${level}] ${prefix}$msg\n";
    }
}

sub log_inc() {
    $LOG_PREFIX++;
}

sub log_dec() {
    $LOG_PREFIX--;
}

sub error {
    my ($msg) = @_;
    logmsg("ERROR", $msg);
}

sub info {
    my ($msg) = @_;
    logmsg("INFO", $msg);
}

sub is_archive {
    my ($path) = @_;
    
    if ($path =~ s/^.*\.//) {
	$path =~ tr/A-Z/a-z/;
	return $ARCHIVE_EXTENSION{$path};
    } else {
	return 0;
    }
}

sub mtime {
    my ($path) = @_;
    return (stat($path))[9];
}


sub remove_dir {
    my ($dir) = @_;

    info("removing directory ${dir}");
    if ($dir =~ /${EXPLODED_DIR}/) { 
	system("rm -rf \"${dir}\"");
	return 1;
	# TODO check for errors
    } else {
	error("not removing directory `${dir}'; bad name");
	return 0;
    }
}

sub unzip {
    my ($zipfile, $dir) = @_;

    if (! -d "${dir}") {
	info("creating directory ${dir}");
	if (! mkdir($dir)) {
	    error("cannot create directory ${dir}");
	    return "";
	} 
    } else {
	if (mtime($zipfile) < mtime($dir)) {
	    info("${dir} already exists and ${zipfile} not modified");
	    return $dir;
	} else {
	    info("${zipfile} has been modified");
	    if (remove_dir($dir)) {
		unzip($zipfile, $dir);
	    }
	}	
    }

    
    info("unzipping ${zipfile} to ${dir}");
    system("cd \"${dir}\"; jar xf \"$zipfile\"");
    
    return ${dir};

}
	

sub explode {
    my ($path) = @_;

    if ($path =~ /^(.*)\/(.*)$/) {
	my ($dir, $name) = ($1, $2);
	info("exploding ${name} in directory ${dir}");
	$dir = $dir . "/${EXPLODED_DIR}";
	if (! -d "${dir}") {
	    info("explode: creating directory ${dir}");
	    if (!mkdir($dir)) {
		error("cannot create directory ${dir}");
		return "";
	    }
	}
	return unzip($path, "${dir}/${name}");
	# TODO return $dir so it can be cleaned up
    } else {
	error("cannot explode bad path $path");
	return "";
    }
}

sub find {
    my ($dir, $func) = @_;
    find2($dir, $func);
}

sub find2 {
    my ($dir, $func) = @_;

    log_inc();

    info("find: directory $dir");
    
    local (*DIR);

    if (!opendir(DIR, "${dir}")) {
	error("cannot read from directory ${dir}");
	return;
    }

    my(@DIRS) = ();
    my(@NEWDIRS) = ();
    my(@FILES) = ();
    while (my $e = readdir(DIR)) {
	next if $e eq "." or $e eq "..";
	my ($path) = "${dir}/${e}";
	info("find: path ${path}");
	if (-d "${path}") {
	    push(@DIRS, $path);
	} else {
	    push(@FILES, $path);
	}
	    
    }

    closedir(DIR);

    info("find: #dirs:    " . @DIRS);
    info("find: #files:   " . @FILES);

    foreach my $f (@FILES) {
	if (is_archive($f)) {
	    info("find: found archive ${f}");
	    my $newdir = explode($f);
	    if ($newdir ne "") {
		info("adding new direcory $newdir");
		push(@NEWDIRS, $newdir);
	    }
	}
    }
    info("find: #newdirs: " . @NEWDIRS);
       
    foreach my $d (@DIRS, @NEWDIRS) {
	info("find: dir $d");
	find($d, $func);
    }

    if ($CLEANUP) {
	foreach my $dir (@NEWDIRS) {
	    # TODO remove the ${EXPLODED_DIR} directory aswell
	    remove_dir($dir);
	}
    }

    foreach my $f (@FILES) {
	info("find: file $f");
	&$func($f);
    }

    log_dec();
}

sub location_paths {
    my ($path) = @_;

    my @parts = split(/\/${EXPLODED_DIR}\//, $path);
    my @paths = ();
    my $cur = $parts[0];
    for (my $i = 1; $i <= $#parts; $i++) {
	my $p = $parts[$i];
	if ($cur ne "") {
	    $cur .= "/";
	}
	if ($p =~ /^([^\/]*)\/(.*)$/) {	  
	    push(@paths, "${cur}$1");
	    $cur = $2;
	} else {
	    push(@paths, "${cur}$p");
	    $cur = "";
	}
    }
    push(@paths, $cur);

    return @paths;
}

sub nice_path {
    my (@paths) = @_;

    if ($#paths <= 0) {
	return $paths[0];
    } else {
	my $p1 = $paths[0];
	shift @paths;
	return "$p1(" . nice_path(@paths) . ")"; 
    }
}
    
sub nice2_path {
    my (@paths) = @_;

    if ($#paths <= 0) {
	print STDERR "POSTFIX 1: $paths[0]\n";
	return $paths[0];
    } else {
	my $p1 = $paths[0];
	print STDERR "POSTFIX n: $p1\n";
	shift @paths;
	return nice2_path(@paths) . " ($p1)";
    }
}
    
sub echo_op {
    my ($path) = @_;
    print nice_path(location_paths($path)) , "\n";
}

find($ARGV[0], 'echo_op');

