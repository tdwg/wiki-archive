<?php

# =====================================================================
function convertWiki() {

  $heading = '---+!! %TOPIC%

';
  $handle = opendir('./');

  print "Processing current directory\n";
  
  while (false !== ($topicFile = readdir($handle))) {

# skip non-topic files 
    if (substr($topicFile, strlen($topicFile) - 4) != '.txt') {
      print "Skipping file: $topicFile\n";
      continue;
    }
     
    print "Processing file: $topicFile\n";
     
    # read topic content into variable
    $content = file_get_contents($topicFile);
    
    # check out topic file
    #checkOut($topicFile, "-l");
    
    # overwrite file adding heading to the beginning
    writeToFile($topicFile, $heading . $content);
    
    # check version back in
    checkIn($topicFile, "-u", 'TWikiGuest', '2007-03-06 17:30:00+00', 'Added topic name via script');
  }
}

# =====================================================================
function checkIn($filename, $options, $user, $date, $log_msg) {
  $cmd = "ci $options -q -w$user -d\"$date\" $filename";
  $pipe = popen("$cmd", 'w');
  if (!$pipe) { 
    print "pipe failed for $filename.\n"; 
    return ""; 
  }
  fputs($pipe, "$log_msg\n.\n");
  pclose($pipe);
}

# =====================================================================
function checkout($filename, $options) {
  $cmd = "co $options -q $filename";
  if (system($cmd)) { 
    print "Cannot check out file $filename. Command: $cmd\n"; 
  }
}

# =====================================================================
function writeToFile($filename, $content, $flags = 'w') {
  if (!$file = fopen($filename, $flags)) 
    return 0;
  
  fwrite($file, $content);
  fclose($file);
  return 1;
}

# =====================================================================
#  Main
# =====================================================================

convertWiki();

# =====================================================================

?>