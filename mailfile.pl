#!/usr/bin/perl

 use MIME::Words qw(:all);
 use File::Copy;
 use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

my $expiration_date = "";
my $config_dir = "/etc/mailfile/";
my $user_address = "";
my $user = "";
my $exit_code = "";
my $link_name = "";
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

my $LOG_FILE = "/var/mail/vmail/mail.log";
open my $log, ">", $LOG_FILE or die("Could not open file. $!");

open(my $mail, '>:encoding(UTF-8)', "$temp_dir$temp_file");
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1455116957.M815148P10554.gar-nich.net,S=5295,W=5390') #Sabine help mail
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454938904.M730684P4521.gar-nich.net,S=42303,W=42918') #simple folder 2 files
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454939017.M940764P4683.gar-nich.net,S=42495,W=43117') #simple zip 2 files
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454858578.M538173P16450.gar-nich.net,S=42520,W=43142') #complex folder 2 files
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454842686.M860959P14143.gar-nich.net,S=9505,W=9681') #help
#open(my $fh, '<:encoding(UTF-8)', '/var/mail/vmail/gar-nich.net/downloads/mail/new/1454846794.M773903P14619.gar-nich.net,S=23893,W=24271') #zip, but 1 file
# or die "Could not open file $!";

#foreach $line ( <$fh> ) { 
foreach $line ( <STDIN> ) {
	print $mail $line;
	print $log $line;
	if ($line =~ "charset"
		and $charset eq "") {
		chomp($line);
		$charset = substr $line, 9;
		binmode($fh, ":encoding($charset)") or warn "invalid Charset found"; #STDIN
		print $log "Charset: $charset\n";
	}
	elsif ($line =~ "Subject: ") {
		if (lc($line) =~ "subject: help" or
				lc($line) =~ "subject: hilfe" or
				lc($line) =~ "subject: anleitung") {
			$exit_code = "help";
			print $log "Help needed\n";
		}
		else {#if (lc($line) =~ "zip") {
			$link_name = substr $line, index($line, 'Subject:') + 9;
			$link_name =~ s/^\s+|\s+$//g;
			$link_name = decode_mimewords($link_name);
			$link_name =~ s/\s/_/g;
			print $log "Encoded Subject: <$link_name>\n";
		}
	}
	elsif ($line =~ "DAUER:" 
			and $expiration_date eq "") {
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
	elsif ($line =~ /^From.*/) {
		($user_address) = $line =~ /<(.*?)>/ ;
        ($user) = $user_address =~ /(.*?)@/;
	}

}
close $fh;

#sanity checks:
#####debug######
#$expiration_date = "234";
#$user = "alex";
#####debug######

if ($exit_code eq "") {
	if ($user_address eq "") {
		$user_address = "$user\@gar-nich.net";
		$exit_code = "no_address";
	}
	elsif ($expiration_date eq "") {
		$exit_code = "no_expiration";
	}
	else {
		my @files = `/usr/bin/munpack -C $temp_dir $temp_dir$temp_file`;
		#print @files;
		#delete the plain/text file:
		@files = grep { $_ !~ "desc" } @files;
		@files = grep { $_ !~ "smime.p7" } @files;
		my $is_empty = grep { $_ =~ "Did not find anything to unpack" } @files;
		if ($is_empty ne "0") {
			$exit_code = "no_files";
		}
		else {
			print $log @files;
			foreach my $i (0 .. $#files) {
				$files[$i] = substr $files[$i], 0, index($files[$i], ' ');
			}
			my $path = processFiles(@files);
			$encoded_link = encodeLink($path);
			print $log "$encoded_link\n";
		}
	}
}
print $log "Exit-Code: $exit_code\n";

if ($exit_code eq "help") {
	#"=?utf-8?b?".base64_encode($Mailbetreff)."?=";
	my $subject = "=?utf-8?q?".encode_mimewords("Wie erstelle ich einen Download-link für mich?äöü à")."?=";
	send_mail($user_address, $subject, $help_file);
}
elsif ($exit_code eq "no_files") {
	send_mail($user_address, "Keine Dateien gefunden :'(", $no_files_file);
}
elsif ($exit_code eq "no_expiration") {
	send_mail($user_address, "Kein Ablaufdatum gefunden", $no_date_file);
}
elsif ($exit_code eq "invalid_time") {
   send_mail($user_address, "Falsche Zeitdauerangabe", $invalid_date_file);
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
	print $log "generating atd command: " . `echo 'rm $download_folder$link_name && echo "Die von Dir irgendwann hochgeladene Datei: $link_name wurde soeben gelöscht." | mail alex@gar-nich.net -s "Abgelaufene Datei gelöscht!"' | at now + 1min`;
}
#print {$mail};
close $mail;

sub send_mail { #Subject, Body
	my ($to, $subject, $content) = @_;
	my $from = 'downloads@gar-nich.net';
	print $log "Mail to $to: $subject Content: $content\n";
	open(MAIL, "|/usr/sbin/sendmail -t");
	# Email Header
	print MAIL "To: $to\n";
	print MAIL "From: $from\n";
	print MAIL "Subject: $subject\n\n";
	# Email Body
	if (-e "$config_dir$content" ) {
		print $log "Lade Nachricht aus Template\n";
		open my $mail_file, '<', "$config_dir$content" 
				or die "can't open $content: $!";
		my $mail_body = do { local $/; <$mail_file> }; #read the whole file into mail_body
		print MAIL $mail_body;
#		while (<$msg_line>) {
	#    	chomp;
#			print MAIL $msg_line;
#		}
		close $mail_file or die "can't close $content: $!";
	}
	else {
		print $log "Sending Content: $content\n";
		print MAIL $content;
	}
	close(MAIL);
	print $log "Mail sent\n";
}
sub processFiles {
	my (@files) = @_;
	my $pathToEncode = "";
	print "Files: @files";
	if ($#files == 0) {
		print "Single-File found\n";
		move("$temp_dir$files[0]", "$download_folder$files[0]");
		chmod 0644, "$download_folder$files[0]";
		$pathToEncode = "$nginx_location$files[0]";
		$link_name = $files[0];
	}
	else { #if (lc($link_name) =~ /zip$/) {
		print "Files to ZIP found\n";
		if (lc($link_name) !~ /zip$/) {$link_name = $link_name.".zip"}
		$pathToEncode = "$nginx_location$link_name";
		my $zip = Archive::Zip->new();
		my $file_member = "";
		foreach $file (@files) {
			$file_member = $zip->addFile("$temp_dir$file", $file);
			$file_member->desiredCompressionMethod(COMPRESSION_DEFLATED);
			$file_member->desiredCompressionLevel( 9 );
		}
		unless ( $zip->writeToFileNamed("$download_folder$link_name") == AZ_OK ) {die "Couldnt write Zip file"}
		chmod 0644, "$download_folder$link_name";
		foreach $file (@files) {
			unlink "$temp_dir$file";
        }
	}
#	else {
#		print "Files -> Folder";
#		my $i = 0;
#		my $new_folder = $link_name;
#		#if ($new_folder eq "") {$new_folder = "download_folder"} #not needed, since default value = download_folder
#		while (-d "$download_folder$new_folder") {
#			$new_folder = $link_name . $i;
#			$i++;
#		}
#		$new_folder = "$new_folder/";
#		mkdir "$download_folder$new_folder";
#		chmod 0755, "$download_folder$new_folder" 
#					or print $log "Couldn't change Permissions on directory";
#		foreach $file (@files) {
#			move("$temp_dir$file", "$download_folder$new_folder$file") 
#					or print $log "Couldn't move $temp_dir$file to $download_folder$new_folder$file: $!";
#			chmod 0644, "$download_folder$new_folder$file";
 #       }
#		$pathToEncode = "$nginx_location$new_folder";
#	}
	return $pathToEncode;
}

sub encodeLink {
	my ($path) = @_;
	print $log "\nExpiration:\n$expiration_date\n";
	print $log "Pfad:\n$path\n";
	print $log "Secret:\n<$nginx_secret>\n";
	my $hash = `echo -n "$expiration_date$path$nginx_secret" | openssl md5 -binary | openssl base64 | tr +/ -_ | tr -d =`;
	chomp($hash);
    return "https://gar-nich.net".$path."?md5=".$hash."&expires=".$expiration_date;
    #http://gar-nich.net/downloads/dead?md5=GeqVkfkrcgRkDXVAVlcvYQ&expires=1454779728
}
