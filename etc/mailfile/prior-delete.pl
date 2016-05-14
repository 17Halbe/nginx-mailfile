#!/usr/bin/perl
	
my $LOG_FILE = "/var/mail/vmail/pre.log";
open my $log, ">", $LOG_FILE or die("Could not open file. $!");
print "Logfile geöffnet";
my $delete_file = "templates/file_deleted.mail";
my $config_dir = "/etc/mailfile/";
my $link_name = "Some_File";
    open my $mail_file, '<', "$config_dir$delete_file" or die "can't open $delete_file: $!";
    print "Mailfile geöffnet";
	my $mail_body = do { local $/; <$mail_file> };
    $mail_body = sprintf $mail_body, $link_name;
#    my $command = qq(echo 'rm "$download_folder$link_name" && echo "$mail_body" | /usr/bin/mail -a "From: downloads@gar-nich.net" -s "Abgelaufene Milch gelöscht!" $user_address');
 #   print $log "##############################################\nFunktioniert: $command";
  #  `$command | at now`;
	send_mail ('alex@gar-nich.net',"TEstPRE-MAil",$mail_body);	
    close $mail_file;

sub send_mail { #to, Subject, Body
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

