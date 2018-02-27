capture log close
****************************************
** Load Fuel Economy and Emissions data into a stata dataset
****************************************
clear all
version 15.1
set more off

global USFuelEconomy "${ResearchData}/Transportation/EPA/USFuelEconomy"
global USFuelEconomyVersion 20180223

log using "${USFuelEconomy}/log/2_clean_fueleconomy_data_${USFuelEconomyVersion}.txt", text replace

**************************
** Load fuel economy data
**************************
import delim "${USFuelEconomy}/data/source/${USFuelEconomyVersion}/vehicles.csv", delim(",") case(preserve)

**Clean up data, set variable names, label vars, encode categorical string vars
**Var labels derived directly from data documentation
encode atvType, gen(AlternativeTechType)
label var AlternativeTechType "Type of alternative fuel or advanced technology vehicle"
drop atvType

rename barrels08 AnnualFuel1bbl
label var AnnualFuel1bbl "Annual petroleum consumption for FuelType1 (bbl)"

rename barrelsA08 AnnualFuel2bbl 
label var AnnualFuel2bbl "Annual petroleum consumption for FuelType2 (bbl)"

rename charge120 ChargeTime120V
label var ChargeTime120V "Time to charge an electric vehicle at 120 V (hr)"

rename charge240 ChargeTime240V
label var ChargeTime240V "Time to charge an electric vehicle at 240 V (hr)"

replace co2 = . if co2 < 0
replace co2TailpipeGpm = . if co2TailpipeGpm < 0
gen CO2PerMileFuel1 = cond(co2TailpipeGpm < ., co2TailpipeGpm, co2)
label var CO2PerMileFuel1 "Tailpipe CO2 for fuelType1 (g/mi)"
drop co2 co2TailpipeGpm

replace co2A = . if co2A < 0
replace co2TailpipeAGpm = . if co2TailpipeAGpm < 0
gen CO2PerMileFuel2 = cond(co2TailpipeAGpm < ., co2TailpipeAGpm, co2A)
label var CO2PerMileFuel2 "Tailpipe CO2 for fuelType2 (g/mi)"
drop co2A co2TailpipeAGpm

**Standardize a couple of varnames so the following loop works
rename combined* comb*
rename (phevCity phevHwy phevComb) (phevcity phevhighway phevcomb)
foreach t in comb city highway {

	if "`t'" == "comb" local T Combined
	else if "`t'" == "city" local T City
	else if "`t'" == "highway" local T Highway
	else {
		di "{err}Unknown drive cycle type {bf:`t'}"
		exit 99
	}
	
	gen MPG1`T'2008 = cond(`t'08U > 0, `t'08U, `t'08)
	label var MPG1`T'2008 "EPA `T' fuel consumption 2008 FuelType1 (MPG)"
	drop `t'08 `t'08U

	gen MPG2`T'2008 = cond(`t'A08U > 0, `t'A08U, `t'A08)
	label var MPG2`T'2008 "EPA `T' fuel consumption 2008 FuelType2 (MPG)"
	drop `t'A08 `t'A08U
	
	rename `t'CD FCCargeDepleting`T' 
	label var FCCargeDepleting`T' "`T' gasoline consumption in charge depleting mode (gallons/100 miles)"

	rename `t'E ElecConsump`T'
	label var ElecConsump`T' "`T' electricity consumption (kWh/100 mi)"

	rename `t'UF UtilityFactor`T'
	label var UtilityFactor`T' "EPA `T' utility factor (share of electricity) for PHEVs"
	
	rename phev`t' MPGePHEV`T'
	label var MPGePHEV`T' "EPA composite gasoline-electricity `T' MPGe for PHEVs"

}


gen byte EngineCylinders = cond(real(cylinders) < ., real(cylinders), .a) if !missing(cylinders)
label var EngineCylinders "Number of engine cylinders"
drop cylinders

gen float EngineDisplacement = cond(real(displ) < ., real(displ), .a)
label var EngineDisplacement "Engine displacement (L)"
drop displ

encode drive, gen(DriveType)
label var DriveType "Drive axel type"

rename engId EPAEngineID
label var EPAEngineID "EPA Engine model ID"

**Large amount of information encoded in the engine description.
**Parse some of it out into indicators
**See http://www.fueleconomy.gov/feg/findacarhelp.shtml#engine
**Define a simple program to identify and flag attributes
program define FlagAttribute
	syntax newvarname, DESCription(string) LABel(string asis)
	
	gen byte `varlist' = strpos(eng_dscr, "`description'") > 0
	replace eng_dscr = trim(itrim(subinstr(eng_dscr, "`description'","", .))) if `varlist'
	label var `varlist' `label'
end

FlagAttribute GasGuzzler, desc(GUZZLER) lab("Vehicle subject to gas guzzler tax")
FlagAttribute UseE85, desc(E85) lab("Vehicle uses E85")
FlagAttribute IsFFV, desc(FFV) lab("Vehicle is flex-fuel")
FlagAttribute isPHEV, desc(PHEV) lab("Plug-in hybrid electric vehicle")
FlagAttribute isHEV, desc(HEV) lab("Hybrid electric vehicle")
FlagAttribute isPZEV, desc(PZEV) lab("Partial zero emissions vehicle")
FlagAttribute isULEV, desc(ULEV) lab("Ultra low emissions vehicle")
FlagAttribute isZEV, desc(ZEV) lab("Zero emissions vehicle")
FlagAttribute hasFFS, desc(FFS) lab("Vehicle has Feedback Fuel System")
FlagAttribute hasTurbo, desc(TRBO) lab("Vehicle has a turbo charger")
FlagAttribute hasTurbo2, desc(TURBO) lab("Temp")
FlagAttribute hasTurbo3, desc(TC) lab("Temp")
replace hasTurbo = hasTurbo | hasTurbo2 | hasTurbo3
drop hasTurbo2 hasTurbo3

FlagAttribute hasSupercharger, desc(S-CHARGE) lab("Vehicle has a supercharger")
FlagAttribute hasSC, desc(SC) lab("Temp")
replace hasSupercharger = hasSupercharger | hasSC
drop hasSC


FlagAttribute valveSOHC4, desc(SOHC-4) lab("Single overhead cam, 4 valves per cylindar")
FlagAttribute valveSOHC, desc(SOHC) lab("Single overhead cam")
FlagAttribute valveDOHC, desc(DOHC) lab("Dual overhead cams")

foreach i of numlist 2 4 8 {
	FlagAttribute valve`i'PS, desc(`i'-VALVE) lab("4 valves per cylindar")
	FlagAttribute valve`i'PS2, desc(`i'VALVE) lab("4 valves per cylindar")
	replace valve`i'PS = valve`i'PS | valve`i'PS2
	drop valve`i'PS2
}



FlagAttribute policeEdition, desc(POLICE) lab("Police Edition")
FlagAttribute isWankel, desc(ROTARY) lab("Vehicle has a Wankel engine")

FlagAttribute hasMPFI, desc(MPFI) lab("Vehicle has multi-port fuel injection")
FlagAttribute hasMPFI2, desc(MFI) lab("temp")
replace hasMPFI = hasMPFI | hasMPFI2
drop hasMPFI2

FlagAttribute hasSPFI, desc(SPFI) lab("Vehicle has single-port fuel injection")
FlagAttribute hasSPFI2, desc(SFI) lab("temp")
replace hasSPFI = hasSPFI | hasSPFI2
drop hasSPFI2
FlagAttribute hasPFI, desc(PFI) lab("Has port fuel injection")

FlagAttribute noCatalyticConverter, desc(NO-CAT) lab("Vehicle does not have a catalytic converter")
FlagAttribute drive2WD, desc(2WD) lab("Vehicle is 2WD")
FlagAttribute drive4WD, desc(4WD) lab("Vehicle is 4WD")
FlagAttribute hasSIDI, desc(SIDI) lab("Vehicle has spark ignition direct injection")

**There a few flags I'll just remove
replace eng_dscr = subinstr(eng_dscr, "350 V8", "", .)
replace eng_dscr = subinstr(eng_dscr, "GM-C", "", .)
replace eng_dscr = subinstr(eng_dscr, "DSL", "", .)

replace eng_dscr = itrim(subinstr(eng_dscr, ";", " ", .))
replace eng_dscr = itrim(subinstr(eng_dscr, ",", " ", .))
replace eng_dscr = itrim(subinstr(eng_dscr, "&", " ", .))
replace eng_dscr = subinstr(eng_dscr,"( ","(",.)
replace eng_dscr = subinstr(eng_dscr, "()","",.)
replace eng_dscr = trim(itrim(eng_dscr))
compress eng_dscr
desc eng_dscr
drop eng_dscr

**evMotor contains free-form text describing EV motors and batteries
**May describe front motor, rear motor, battery capacity, motor details
**Standardize some descriptions
replace evMotor = subinstr(evMotor, "kW-hr", "kWh", .)

gen int EVMotor1Power = .
label var EVMotor1Power "Primary/Front EV motor power (kW)"
gen int EVMotor2Power = .
label var EVMotor2Power "Secondary/Rear EV motor power (kW)"
gen int EVBatteryCapacity = .
label var EVBatteryCapacity "EV Battery capacity (kWh)"
label define EVBatteryTechnology 1 "Li-ion" 2 "Ni-MH"
gen byte EVBatteryTechnology:EVBatteryTechnology = .
label var EVBatteryTechnology "EV Battery technology"


replace EVMotor1Power = real(regexs(1)) if regexm(evMotor, "([0-9]+) ?[kK]W[^h]")
replace evMotor = regexr(evMotor, "([0-9]+) ?[kK]W[^h]", "")

replace EVMotor1Power = real(regexs(1)) if regexm(evMotor, "([0-9]+) ?[kK][wW]$")
replace evMotor = regexr(evMotor,"([0-9]+) ?[kK][wW]$", "")

replace EVMotor1Power = real(regexs(1)) if regexm(evMotor, "([0-9]+) \(front\) ([0-9]+) \(rear\)")
replace EVMotor2Power = real(regexs(2)) if regexm(evMotor, "([0-9]+) \(front\) ([0-9]+) \(rear\)")
replace evMotor = regexr(evMotor,"([0-9]+) \(front\) ([0-9]+) \(rear\)", "")

replace EVMotor1Power = real(regexs(1)) if regexm(evMotor, "([0-9]+) and ([0-9]+) ?[kK][wW][^h]")
replace EVMotor2Power = real(regexs(2)) if regexm(evMotor, "([0-9]+) and ([0-9]+) ?[kK][wW][^h]")
replace evMotor = regexr(evMotor,"([0-9]+) and ([0-9]+) ?[kK][wW][^h]", "")

replace EVMotor1Power = real(regexs(1)) if regexm(evMotor, "2 @ ([0-9]+) [kK][wW][^h]")
replace EVMotor2Power = real(regexs(1)) if regexm(evMotor, "2 @ ([0-9]+) [kK][wW][^h]")
replace evMotor = regexr(evMotor,"2 @ ([0-9]+) [kK][wW][^h]", "")

replace EVBatteryCapacity = real(regexs(1)) if regexm(evMotor, "([0-9]+) kWh battery pack")
replace evMotor = regexr(evMotor,"([0-9]+) kWh battery pack", "")

replace EVBatteryTechnology = "Ni-MH":EVBatteryTechnology if strpos(evMotor, "Ni-MH")
replace evMotor = subinstr(evMotor, "Ni-MH","",.)
replace EVBatteryTechnology = "Li-ion":EVBatteryTechnology if strpos(evMotor, "Li-Ion")
replace evMotor = subinstr(evMotor, "Li-Ion", "", .)

tab evMotor
**There is more info here. Not clear how to use it
drop evMotor


rename feScore EPAFuelEconomyScore
label var EPAFuelEconomyScore "EPA Fuel Economy Score"

**Exclude the fuel cost vars. These are dependent on current fuel prices
**And are more resonably computed on-demand
drop fuelCost08 fuelCostA08

**Encode fuel types. Note that the "fuelType" variable just
**combines info from fuelType1 and fuelType2. Exclude the redundant var
encode fuelType1, gen(FuelType1) label(FuelType)
encode fuelType2, gen(FuelType2) label(FuelType)
drop fuelType fuelType1 fuelType2
label var FuelType1 "Primary fuel type"
label var FuelType2 "Alternative fuel type"

rename ghgScore EPAGHGScore1
label var EPAGHGScore1 "EPA GHG Score FuelType1"

rename ghgScoreA EPAGHGScore2
label var EPAGHGScore2 "EPA GHG Score FuelType2"


replace GasGuzzler = 1 if guzzler != ""
assert GasGuzzler == 0 if guzzler == ""
drop guzzler

rename id RecordID
label var RecordID "Vehicle Record ID"

**Standardize some varnames so the following loop works
rename (hlv hpv) (lvh pvh)
foreach t in h 2 4 {
	if "`t'" == "h" local T Hatchback
	if "`t'" == "2" local T 2Door
	if "`t'" == "4" local T 4Door
	
	rename (lv`t' pv`t') (LuggageVolume`T' PassengerVolume`T')
	label var LuggageVolume`T' "Luggage Volumne `T' (ft^3)"
	label var PassengerVolume`T' "Passenger Volumne `T' (ft^3)"
}

rename make Make
label var Make "Vehicle Make"

rename mfrCode ManufacturerCode
label var ManufacturerCode "3-character manufacturer code"

rename model Model
label var Model "Model name"

assert inlist(mpgData, "Y", "N") if !missing(mpgData)
gen byte hasMPGData = cond(mpgData == "Y", 1, 0) if !missing(mpgData)
drop mpgData
label var hasMPGData "Has EPA MPG data"


assert inlist(phevBlended, "true", "false") if !missing(phevBlended)
gen byte BlendedModePHEV = cond(phevBlended == "true", 1, 0) if !missing(phevBlended)
label var BlendedModePHEV "True if this vehicle operates on a blend of gasoline and electricity in charge depleting mode"
drop phevBlended

forvalues i=1/2 {
	if `i' == 1 local A
	else if `i' == 2 local A A
	else {
		di "{err}Unknown fuel type {bf:`i'}
		exit 99
	}
	rename rangeCity`A' RangeCity`i'
	label var RangeCity`i' "City range using FuelType`i' (miles)"
	rename rangeHwy`A' RangeHighway`i'
	label var RangeHighway`i' "Highway range using FuelType`i' (miles)"
	rename range`A' RangeCombined`i'
	label var RangeCombined`i' "Combined range using FuelType`i' (miles)"
	
	rename (UCity`A' UHighway`A') (UnadjMPGCity`i' UnadjMPGHighway`i')
	label var UnadjMPGCity`i' "Unadjusted city MPG for FuelType`i'"
	label var UnadjMPGHighway`i' "Unadjusted highway MPG for FuelType`i'"
	
}

label define TransmissionType 1 "Manual" 2 "Automatic" 3 "Automatic, lockup" 4 "Automatic, select shift" ///
	5 "Automated manual" 6 "Automated manual, select shift" 7 "Automatic, variable" 8 "CVT"

gen byte TransmissionType:TransmissionType = .
**Convert the trany field to standarized codes
**see http://www.fueleconomy.gov/feg/findacarhelp.shtml#trany
replace trany = "A" + regexs(1) if regexm(trany, "^Automatic ([0-9]+)-spd$")
replace trany = "M" + regexs(1) if regexm(trany, "^Manual ([0-9]+)-spd$")
replace trany = regexs(1) + regexs(2) if regexm(trany, "\(([A-Z]+)-?([A-Z]?[0-9]+)\)")
replace trany = "M4" if trany == "Manual 4-spd Doubled"


replace TransmissionType = "Automatic":TransmissionType if regexm(trany, "^A[0-9]+$")
replace TransmissionType = "Automatic, lockup":TransmissionType if regexm(trany, "^L[0-9]+$")
replace TransmissionType = "Automatic, select shift":TransmissionType if regexm(trany, "^S[0-9]+$")
replace TransmissionType = "Automated manual":TransmissionType if regexm(trany, "^AM[0-9]+$")
replace TransmissionType = "Automated manual, select shift":TransmissionType if regexm(trany, "^AMS[0-9]+$")
replace TransmissionType = "Automatic, variable":TransmissionType if regexm(trany, "^AVS[0-9]+$")
replace TransmissionType = "Manual":TransmissionType if regexm(trany, "^M[0-9]+$")
replace TransmissionType = "CVT":TransmissionType if trany == "Automatic (variable gear ratios)"
label var TransmissionType "Vehicle transmission type"

gen byte TransmissionGears = real(regexs(1)) if regexm(trany, "^[A-Z]+([0-9]+)$")
label var TransmissionGears "Tranmission number of gears"

**There are other details of the transmission stored in trans_dscr
**That currently aren't extracted
tab trany if TransmissionType == .
drop trany trans_dscr

encode VClass, gen(EPAVehicleClass)
label var EPAVehicleClass "EPA Vehicle Class"
drop VClass

rename year ModelYear

drop youSaveSpend



replace hasSupercharger = 1 if sCharger == "S"
replace hasTurbo = 1 if tCharger == "T"
drop sCharger tCharger

encode c240Dscr, gen(EVCharger)
encode c240bDscr, ge(EVChargerAlternate) label(EVCharger)
drop c240Dscr c240bDscr
label var EVCharger "Primary EV Charger type"
label var EVChargerAlternate "Alternate EV Charger type"



rename charge240b EVTimeToChargeAlternate
label var EVTimeToChargeAlternate "Time to charge EV on 240V using alternate charger (hr)"

drop createdOn modifiedOn

assert inlist(startStop, "Y", "N") if !missing(startStop)
gen byte hasStartStop = cond(startStop == "Y", 1, 0) if !missing(startStop)
drop startStop
label var hasStartStop "Vehicle equiped with start-stop technology"

**clear typo in Drive. This is a code for a transmission
**It's a BMW i3s, so it's RWD
assert Make == "BMW" if drive == "Automatic (A1)"
replace drive = "Rear-Wheel Drive" if drive == "Automatic (A1)"
encode drive, gen(DrivetrainType)
drop drive
label var DrivetrainType "Vehicle drivetrain type"


order RecordID Make Model ModelYear

compress


save "${USFuelEconomy}/data/out/${USFuelEconomyVersion}/EPAFuelEconomy.dta", replace


log close









