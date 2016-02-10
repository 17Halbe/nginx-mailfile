#!/usr/bin/perl

 use URI::Escape;
 use MIME::Words qw(:all);
 use File::Copy;
 use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

my $expiration_date = "";
my $config_dir = "/etc/mailfile/";
my $user_address = "";
my $user = "";
my $exit_code = "";
my $link_name = "download_folder";
my $encoded_link = "";
my $charset = "";

#require ($config_dir."mailfile-config.pl");
open(CONFIG,$config_dir."mailfile.conf") or die "No config file found: $_";

no strict 'refs';
while (<CONFIG>) {
	chomp;                  # no newline
    s/#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;     # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
	$value =~ s/^"//;	    # no leading "
	$value =~ s/"$//;		# no trailing "
	$$var = $value;
}
close CONFIG;

open(my $mail, '>:encoding(UTF-8)', "$temp_dir$temp_file");
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454938904.M730684P4521.gar-nich.net,S=42303,W=42918') #simple folder 2 files
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454939017.M940764P4683.gar-nich.net,S=42495,W=43117') #simple zip 2 files
open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454858578.M538173P16450.gar-nich.net,S=42520,W=43142') #complex folder 2 files
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454842686.M860959P14143.gar-nich.net,S=9505,W=9681') #help
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454846794.M773903P14619.gar-nich.net,S=23893,W=24271') #zip, but 1 file
 or die "Could not open file $!";

foreach $line ( <$fh> ) { #<STDIN>
	print $mail $line;
	if ($line =~ "charset"
		and $charset eq "") {
		chomp($line);
		$charset = substr $line, 9;
		binmode($fh, ":encoding($charset)") or warn "invalid Charset found"; #STDIN
		print "Charset: $charset\n";
	}
	elsif ($line =~ "Subject: ") {
		if (lc($line) =~ "subject: help" or
				lc($line) =~ "subject: hilfe" or
				lc($line) =~ "subject: anleitung") {
			$exit_code = "help";
		}
		else {#if (lc($line) =~ "zip") {
			$link_name = substr $line, index($line, 'Subject:') + 9;
			$link_name =~ s/^\s+|\s+$//g;
			$link_name = decode_mimewords($link_name);
			$link_name =~ s/\s/_/g;
			print "Encoded Subject: <$link_name>\n";
		}
	}
	elsif ($line =~ /^DAUER:/) {
		$expiration_date = substr $line, index($line, 'DAUER:') + 7;
		$expiration_date =~ s/^\s+|\s+$//g;
		my ($count, $multi) = split / /, $expiration_date;
		if (lc($multi) =~ "tag") {$multi = 86400}
		elsif (lc($multi) =~ "woche") {$multi = 604800}
		elsif (lc($multi) =~ "monat") {$multi = 2419200}
		elsif (lc($multi) =~ "jahr") {$multi = 31536000}
		else {$exit_code = "invalid_time";last;}
		$expiration_date = time() + $count * $multi;
	}
	elsif ($line =~ "From") {
        $user_address = substr $line, index($line, '<') + 1, index($line, '>') - index($line, '<') - 1;
        $user = substr $line, index($line, '<') + 1, index($line, '@') - index($line, '<') - 1;
	}

}
close $fh;

#sanity checks:
#####debug######
#$expiration_date = "234";
#$user = "alex";
#####debug######


if ($user_address eq "") {
	$user_address = "$user\@gar-nich.net";
	$exit_code = "no_address";
}
elsif ($expiration_date eq "") {
	$exit_code = "no_expiration";
}
elsif ($exit_code eq "") {
	my @files = `/usr/bin/munpack -C $temp_dir $temp_dir$temp_file`;
	#print @files;
	#delete the plain/text file:
	@files = grep { $_ !~ "desc" } @files;
	my $is_empty = grep { $_ =~ "Did not find anything to unpack" } @files;
	if ($is_empty ne "0") {
		$exit_code = "no_files";
	}
	else {
		print @files;
		foreach my $i (0 .. $#files) {
			$files[$i] = substr $files[$i], 0, index($files[$i], ' ');
		}
		my $path = processFiles(@files);
		$encoded_link = encodeLink($path);
		print "$encoded_link\n";
	}
}
print "Exit-Code: $exit_code";

if ($exit_code eq "help") {
#	send_mail($user_address, "Wie erstelle ich einen Download-link für eine Datei", $help_file);
}
elsif ($exit_code eq "no_files") {
#	send_mail($user_address, "Keine Dateien gefunden :'(", $no_files_file);
}
elsif ($exit_code eq "no_expiration") {
#	send_mail($user_address, "Kein Ablaufdatum gefunden", $no_date_file);
}
elsif ($exit_code eq "invalid_time") {
#   send_mail($user_address, "Falsche Zeitdauerangabe", $invalid_date_file);
}
elsif ($exit_code eq "no_address") {
	send_mail($user_address, "Tut mir Leid..", $denied_file);
	send_mail("alex\@gar-nich.net", "Unauthorisierter Zugriff von Nutzer: >$user< (Addresse: >$user_address<)!", $mail);
}
else {
	open my $mail_file, '<', "$config_dir$success_file" or die "can't open $file: $!";
	my $mail_body = do { local $/; <$mail_file> }; #read the whole file into mail_body
	my $expire_date = scalar localtime($expiration_date);
	my $mail_body = sprintf $mail_body, $encoded_link, $expire_date;
	send_mail($user_address, "Link wurde erstellt!", $mail_body);

}
close $mail;

sub send_mail { #Subject, Body
	my ($to, $subject, $content) = @_;
	my $from = 'downloads@gar-nich.net';

	open(MAIL, "|/usr/sbin/sendmail -t");
	# Email Header
	print MAIL "To: $to\n";
	print MAIL "From: $from\n";
	print MAIL "Subject: $subject\n\n";
	# Email Body
	if (-e $content ) {
		open my $msg_line, '<', "$config_dir$file" or die "can't open $file: $!";
		while (<$msg_line>) {
	#    	chomp;
			print MAIL $msg_line;
		}
		close $msg_line or die "can't close $file: $!";
	}
	else {
		print MAIL $content;
	}
	close(MAIL);
}
sub processFiles {
	my (@files) = @_;
	my $pathToEncode = "";
	if ($#files == 0) {
		move("$temp_dir$files[0]", "$download_folder$files[0]");
		$pathToEncode = "$nginx_location$files[0]";
	}
	elsif (lc($link_name) =~ /zip$/) {
		print "MAKE A ZIP\n";
		$pathToEncode = "$nginx_location$link_name";
		my $zip = Archive::Zip->new();
		my $file_member = "";
		foreach $file (@files) {
			$file_member = $zip->addFile("$temp_dir$file", $file);
			$file_member->desiredCompressionMethod(COMPRESSION_DEFLATED);
			$file_member->desiredCompressionLevel( 9 );
		}
		unless ( $zip->writeToFileNamed("$download_folder$link_name") == AZ_OK ) {die "Couldnt write Zip file"}
		foreach $file (@files) {
			unlink "$temp_dir$file";
        }
	}
	else {
		my $i = 0;
		my $new_folder = $link_name;
		#if ($new_folder eq "") {$new_folder = "download_folder"} #not needed, since default value = download_folder
		while (-d "$download_folder$new_folder") {
			$new_folder = $link_name . $i;
			$i++;
		}
		print "New Folder: $download_folder$new_folder\n";
		$new_folder = "$new_folder/";
		mkdir "$download_folder$new_folder";
		foreach $file (@files) {
			move("$temp_dir$file", "$download_folder$new_folder$file");
        }
		$pathToEncode = "$nginx_location$new_folder";
	}
	print $pathToEncode."\n";
	return $pathToEncode;
}

sub encodeLink {
	my ($path) = @_;
	print "\nExpiration:\n$expiration_date\n";
	print "Pfad:\n$path\n";
	print "Secret:\n<$nginx_secret>\n";
	my $hash = `echo -n "$expiration_date$path$nginx_secret" | openssl md5 -binary | openssl base64 | tr +/ -_ | tr -d =`;
	chomp($hash);
    return "https://gar-nich.net".$path."?md5=".$hash."&expires=".$expiration_date;
    #http://gar-nich.net/downloads/dead?md5=GeqVkfkrcgRkDXVAVlcvYQ&expires=1454779728
}
# LpjlsecretMC2TBYRaW4On6FwljiUATRAz
#1459742382
#/downloads/BierXTeilX1.odt
