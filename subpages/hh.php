<?php
// Code to randomly generate conjoint profiles to send to a Qualtrics instance

// Terminology clarification: 
// Task = Set of choices presented to respondent in a single screen (i.e. pair of candidates)
// Profile = Single list of attributes in a given task (i.e. candidate)
// Attribute = Category characterized by a set of levels (i.e. education level)
// Level = Value that an attribute can take in a particular choice task (i.e. "no formal education")

// Attributes and Levels stored in a 2-dimensional Array 

// Function to generate weighted random numbers
function weighted_randomize($prob_array, $at_key)
{
	$prob_list = $prob_array[$at_key];
	
	// Create an array containing cutpoints for randomization
	$cumul_prob = array();
	$cumulative = 0.0;
	for ($i=0; $i<count($prob_list); $i++){
		$cumul_prob[$i] = $cumulative;
		$cumulative = $cumulative + floatval($prob_list[$i]);
	}

	// Generate a uniform random floating point value between 0.0 and 1.0
	$unif_rand = mt_rand() / mt_getrandmax();

	// Figure out which integer should be returned
	$outInt = 0;
	for ($k = 0; $k < count($cumul_prob); $k++){
		if ($cumul_prob[$k] <= $unif_rand){
			$outInt = $k + 1;
		}
	}

	return($outInt);

}
                    

$featurearray = array("Gender" => array("Female","Male"),"Education" => array("No formal education","Equivalent to completing fourth grade in the U.S.","Equivalent to completing eighth grade in the U.S.","Equivalent to completing high school in the U.S.","Equivalent to completing two years at college in the U.S.","Equivalent to completing a college degree in the U.S.","Equivalent to completing a graduate degree in the U.S."),"Language Skills" => array("During admission interview, this applicant spoke fluent English","During admission interview, this applicant spoke broken English","During admission interview, this applicant tried to speak English but was unable","During admission interview, this applicant spoke through an interpreter"),"Country of Origin" => array("Germany","France","Mexico","Philippines","Poland","India","China","Sudan","Somalia","Iraq"),"Job" => array("Janitor","Waiter","Child care provider","Gardener","Financial analyst","Construction worker","Teacher","Computer programmer","Nurse","Research scientist","Doctor"),"Job Experience" => array("No job training or prior experience","One to two years","Three to five years","More than five years"),"Job Plans" => array("Has a contract with a U.S. employer","Does not have a contract with a U.S. employer, but has done job interviews","Will look for work after arriving in the U.S.","Has no plans to look for work at this time"),"Reason for Application" => array("Reunite with family members already in U.S.","Seek better job in U.S.","Escape political/religious persecution"),"Prior Entry" => array("Never been to the U.S.","Entered the U.S. once before on a tourist visa","Has visited the U.S. many times before on tourist visas","Spent six months with family members in the U.S.","Entered the U.S. once before without legal authorization"));

$restrictionarray = array(array(array("Job","Financial analyst"),array("Education","No formal education")),array(array("Job","Financial analyst"),array("Education","Equivalent to completing fourth grade in the U.S.")),array(array("Job","Financial analyst"),array("Education","Equivalent to completing eighth grade in the U.S.")),array(array("Job","Financial analyst"),array("Education","Equivalent to completing high school in the U.S.")),array(array("Job","Computer programmer"),array("Education","No formal education")),array(array("Job","Computer programmer"),array("Education","Equivalent to completing fourth grade in the U.S.")),array(array("Job","Computer programmer"),array("Education","Equivalent to completing eighth grade in the U.S.")),array(array("Job","Computer programmer"),array("Education","Equivalent to completing high school in the U.S.")),array(array("Job","Research scientist"),array("Education","No formal education")),array(array("Job","Research scientist"),array("Education","Equivalent to completing fourth grade in the U.S.")),array(array("Job","Research scientist"),array("Education","Equivalent to completing eighth grade in the U.S.")),array(array("Job","Research scientist"),array("Education","Equivalent to completing high school in the U.S.")),array(array("Job","Doctor"),array("Education","No formal education")),array(array("Job","Doctor"),array("Education","Equivalent to completing fourth grade in the U.S.")),array(array("Job","Doctor"),array("Education","Equivalent to completing eighth grade in the U.S.")),array(array("Job","Doctor"),array("Education","Equivalent to completing high school in the U.S.")),array(array("Reason for Application","Escape political/religious persecution"),array("Country of Origin","Germany")),array(array("Reason for Application","Escape political/religious persecution"),array("Country of Origin","France")),array(array("Reason for Application","Escape political/religious persecution"),array("Country of Origin","Mexico")),array(array("Reason for Application","Escape political/religious persecution"),array("Country of Origin","Poland")),array(array("Reason for Application","Escape political/religious persecution"),array("Country of Origin","India")),array(array("Reason for Application","Escape political/religious persecution"),array("Country of Origin","Philippines")));

// Indicator for whether weighted randomization should be enabled or not
$weighted = 0;

// K = Number of tasks displayed to the respondent
$K = 5;

// N = Number of profiles displayed in each task
$N = 2;

// num_attributes = Number of Attributes in the Array
$num_attributes = count($featurearray);


$attrconstraintarray = array(array("Job","Job Experience","Job Plans"));


// Re-randomize the $featurearray

// Place the $featurearray keys into a new array
$featureArrayKeys = array();
$incr = 0;

foreach($featurearray as $attribute => $levels){	
	$featureArrayKeys[$incr] = $attribute;
	$incr = $incr + 1;
}

// Backup $featureArrayKeys
$featureArrayKeysBackup = $featureArrayKeys;

// If order randomization constraints exist, drop all of the non-free attributes
if (count($attrconstraintarray) != 0){
	foreach ($attrconstraintarray as $constraints){
		if (count($constraints) > 1){
			for ($p = 1; $p < count($constraints); $p++){
				if (in_array($constraints[$p], $featureArrayKeys)){
					$remkey = array_search($constraints[$p],$featureArrayKeys);
					unset($featureArrayKeys[$remkey]);
				}
			}
		}
	}
} 
// Re-set the array key indices
$featureArrayKeys = array_values($featureArrayKeys);
// Re-randomize the $featurearray keys
shuffle($featureArrayKeys);

// Re-insert the non-free attributes constrained by $attrconstraintarray
if (count($attrconstraintarray) != 0){
	foreach ($attrconstraintarray as $constraints){
		if (count($constraints) > 1){
			$insertloc = $constraints[0];
			if (in_array($insertloc, $featureArrayKeys)){
				$insert_block = array($insertloc);
				for ($p = 1; $p < count($constraints); $p++){
					if (in_array($constraints[$p], $featureArrayKeysBackup)){
						array_push($insert_block, $constraints[$p]);
					}
				}
				
				$begin_index = array_search($insertloc, $featureArrayKeys);
				array_splice($featureArrayKeys, $begin_index, 1, $insert_block);
			}
		}
	}
}


// Re-generate the new $featurearray - label it $featureArrayNew

$featureArrayNew = array();
foreach($featureArrayKeys as $key){
	$featureArrayNew[$key] = $featurearray[$key];
}
// Initialize the array returned to the user
// Naming Convention
// Level Name: F-[task number]-[profile number]-[attribute number]
// Attribute Name: F-[task number]-[attribute number]
// Example: F-1-3-2, Returns the level corresponding to Task 1, Profile 3, Attribute 2 
// F-3-3, Returns the attribute name corresponding to Task 3, Attribute 3

$returnarray = array();

// For each task $p
for($p = 1; $p <= $K; $p++){

	// For each profile $i
	for($i = 1; $i <= $N; $i++){

		// Repeat until non-restricted profile generated
		$complete = False;

		while ($complete == False){

			// Create a count for $attributes to be incremented in the next loop
			$attr = 0;
			
			// Create a dictionary to hold profile's attributes
			$profile_dict = array();

			// For each attribute $attribute and level array $levels in task $p
			foreach($featureArrayNew as $attribute => $levels){	
				
				// Increment attribute count
				$attr = $attr + 1;

				// Create key for attribute name
				$attr_key = "F-" . (string)$p . "-" . (string)$attr;

				// Store attribute name in $returnarray
				$returnarray[$attr_key] = $attribute;

				// Get length of $levels array
				$num_levels = count($levels);

				// Randomly select one of the level indices
				if ($weighted == 1){
					$level_index = weighted_randomize($probabilityarray, $attribute) - 1;

				}else{
					$level_index = mt_rand(1,$num_levels) - 1;	
				}	

				// Pull out the selected level
				$chosen_level = $levels[$level_index];
			
				// Store selected level in $profileDict
				$profile_dict[$attribute] = $chosen_level;

				// Create key for level in $returnarray
				$level_key = "F-" . (string)$p . "-" . (string)$i . "-" . (string)$attr;

				// Store selected level in $returnarray
				$returnarray[$level_key] = $chosen_level;

			}

			$clear = True;
			// Cycle through restrictions to confirm/reject profile
			if(count($restrictionarray) != 0){

				foreach($restrictionarray as $restriction){
					$false = 1;
					foreach($restriction as $pair){
						if ($profile_dict[$pair[0]] == $pair[1]){
							$false = $false*1;
						}else{
							$false = $false*0;
						}
						
					}
					if ($false == 1){
						$clear = False;
					}
				}
			}
			$complete = $clear;
		}
	}


}

// Return the array back to Qualtrics
print  json_encode($returnarray);
?>
