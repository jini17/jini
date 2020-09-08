<?php

    date_default_timezone_set('Asia/Kuala_Lumpur');

    //format of server entry
	//[ServerName, APP/DB]=>array(username, IP)
	writelog("Server Monitoring Started \n");
	$serverlist = array(
						"Test APP"=>array("dev3-app","34.126.108.217","dev3-app-test.pem"),
						"Test-php74 DB"=>array("test-php74","35.213.188.143","test-php74.pem"),				
					);

	$output	    = array();	

    foreach($serverlist as $host=>$serverdetails) {
		
        $result = shell_exec("ping -W 1 -c1 $serverdetails[1]");
        if(stripos($result, '0 received') !==false){
			writelog("Server[$serverdetails[1]] is unreachable. Please check \n");
		    $output[$host] = array($serverdetails[1],'Server is unreachable. Please check');   

        } else {
           
            if(stripos($host,'APP')===false){ 
				$port = 33060;
				if($serverdetails[1] == '49.236.203.140') {
					$port = 3306;
				}
				$result = check_server($serverdetails[1], 'mysql service',$port);
	        } else {
				$port = 80;
                $result 	= check_server($serverdetails[1], 'apache service', $port);
            }	
			
            if($result){
				writelog($result."\n");
				if($port==33060 || $port == 3306){
					shell_exec("ssh -i /root/.ssh/$serverdetails[2] $serverdetails[0]@$serverdetails[1] 'sudo systemctl restart mysqld'");
				} else {
					shell_exec("ssh -i /root/.ssh/$serverdetails[2] $serverdetails[0]@$serverdetails[1] 'sudo systemctl restart httpd'");
				}	
				$output[$host] = array($serverdetails[1],$result);
            }    
        }
	}		

	if(count($output)>0) {

		$message = '<html><head></head><body>
					<span style="font-family: Tahoma, Geneva, sans-serif; font-size: 10pt;color:#1F497D;">Hi All,<br><span style="font-family: Tahoma, Geneva, sans-serif; font-size: 10pt"></span><span style="font-family: Tahoma, Geneva, sans-serif; font-size: 10pt"><p class="MsoNormal">
					<span style="font-size:11.0pt;font-family:&quot;Calibri&quot;,sans-serif;color:#1F497D;">Its Emergency, few servers are down, please check it. </span></p></span>
					<table style="width: 100%; border-color:#A9A9A9;" border="3" cellpadding="3">
					<tbody>
                        <tr style="height: 21px;background-color: #94ca53;">
                            <td style="height: 21px; width: 10%;color:#fff;"><strong>S.NO</strong></td>
                            <td style="height: 21px; width: 26%;color:#fff;"><strong>Server</strong></td>
                            <td style="height: 21px; width: 21%;color:#fff;"><strong>Status</strong></td>
                        </tr>';
        	$k=1;
        
			foreach($output as $host=>$details) {
				
				$message .= '<tr style="height: 21px;">
								<td style="height: 21px; width: 10%;text-align:center;">'.$k.'</td>
								<td style="height: 21px; width: 27%;">'.$host.' ['.$details[0].']</td>
								<td style="height: 21px; width: 19%;">';
				$message .= $details[1].' </td>';		
				$message .= ' </tr>';
				$k++;
			}
				
		     $message .= '</tbody>
				</table>
				<!-- DivTable.com -->
                <br><br><div>
                <div>&nbsp;<p class="MsoNormal"><span style="color:#2F5496">Thanks &amp; Best Regards,</span>
				<br />Server Admin <br /><br /><br />
				</body></html>';

			include 'PHPMailer/PHPMailerAutoload.php';
			
			$toemail = "jitu@secondcrm.com";
			//email send to all users

    		$mail = new PHPMailer();
			$mail->IsSMTP();
			$mail->Host = 'smtp.gmail.com';
			$mail->Port = '587';
			$mail->SMTPAuth = true;
			$mail->SMTPSecure = 'tls';
			$mail->Username = '2ndcrm@gmail.com';
			$mail->Password = 'test123$$';
			$mail->ContentType = "text/html";
			$mail->WordWrap=50;
			//$mail->SMTPDebug=2;
			//$mail->IsHTML(true);
			$mail->From = 'fazrul@softsolvers.com';
			$mail->FromName = 'Server Admin';
			$mail->AddAddress( $toemail);
			#$mail->AddAddress('norahimah@secondcrm.com','Rahimah');	
			#$mail->AddAddress('sarab@softsolvers.com.my','Ms. Sarab');	
			#$mail->AddAddress('support@secondcrm.com','Support');	
			#$mail->AddCC('nirbhay@secondcrm.com','Nirbhay');
			#$mail->AddCC('deep@softsolvers.com.my','Deep');
			$mail->AddCC('fazrul@softsolvers.com','Fazrul');
			   
		   
			
			//Set the message subject
			$mail->Subject = "Emergency Production Server down at ".date('d-m-Y H:i:s');
			
			//Send the message as HTML
			//$mail->MsgHTML( stripslashes( $message ) ); 
		
			$mail->Body =$message;
			//Display success or error messages
			if( !$mail->Send() )
			{
				echo "Failed to send email\n";
				writelog("Failed to send email \n");
			} else {
				writelog("Email successfully send \n");
				echo "Email successfully send \n";
			}
		
	} else {
		echo "All servers running fine \n";
		writelog("All servers running fine \n");
	}
	writelog("Monitoring Script ended \n");

	function pingAddress($ip) {
	    $pingresult = exec("/bin/ping -n 3 $ip", $outcome, $status);
	    if (0 == $status) {
        	$status = "alive";
	    } else {
        	$status = "dead";
	    }
	    echo "The IP address, $ip, is  ".$status;
	}
    
    function check_server($host, $service, $port){

		$connection = @fsockopen($host, $port, $errno, $errstr, 30);
		
        if (!is_resource($connection))
        {
		    return $service.' was DOWN for '.$host.' on port '.$port. '. Now its running';
        }
        fclose($connection);
	}
	
	function writelog($string){

		$logfile = 'logs/serverlog_'.date('Ymd').'.log';
		if (checklogfile($logfile)) {
		  	$file = fopen($logfile, 'a');
			fwrite($file, "[". date("Y-m-d H:i:s") ."]" . $string . "\n");
		} else {
		  	$file = fopen($logfile, 'w');
			fwrite($file, "[". date("Y-m-d H:i:s") ."]" . $string . "\n");
		}
		fclose($file);
	}

	function checklogfile($logfile){
		
		if (file_exists($logfile)) {
			return true;
		} else {
			return false;
		}

	}
?>	
