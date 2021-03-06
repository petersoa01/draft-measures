library AdvancedIllnessandFrailtyExclusion_FHIR4 version '4.0.000'

using FHIR version '4.0.0'

include FHIRHelpers version '4.0.0' called FHIRHelpers
include MATGlobalCommonFunctions_FHIR4 version '4.0.000' called Global

codesystem "LOINC": 'urn:oid:2.16.840.1.113883.6.1'

valueset "Acute Inpatient": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1083'
valueset "Advanced Illness": 'urn:oid:2.16.840.1.113883.3.464.1003.110.12.1082'
valueset "Care Services in Long-Term Residential Facility": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1014'
valueset "Dementia Medications": 'urn:oid:2.16.840.1.113883.3.464.1003.196.12.1510'
valueset "ED": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1085'
valueset "Frailty Device": 'urn:oid:2.16.840.1.113883.3.464.1003.118.12.1300'
valueset "Frailty Diagnosis": 'urn:oid:2.16.840.1.113883.3.464.1003.113.12.1074'
valueset "Frailty Encounter": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1088'
valueset "Frailty Symptom": 'urn:oid:2.16.840.1.113883.3.464.1003.113.12.1075'
valueset "Nonacute Inpatient": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1084'
valueset "Nursing Facility Visit": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1012'
valueset "Observation": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1086'
valueset "Outpatient": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1087'

code "Birth date": '21112-8' from "LOINC" display 'Birth date'

parameter "Measurement Period" Interval<DateTime>

context Patient

define "Advanced Illness Diagnoses":
    [Condition: "Advanced Illness"] AdvancedIllnessDiagnosis

define "Outpatient Encounters with Advanced Illness":
	( [Encounter: "Outpatient"]
		union [Encounter: "Observation"]
		union [Encounter: "ED"]
		union [Encounter: "Nonacute Inpatient"] ) OutpatientEncounter
		with "Advanced Illness Diagnoses" AdvancedIllnessDiagnosis
            such that exists (
                OutpatientEncounter.diagnosis.condition Condition
                    where EndsWith(Condition.reference, AdvancedIllnessDiagnosis.id)
            )
            and OutpatientEncounter.period starts 2 years or less before
			end of "Measurement Period"

define "Long Term Care Periods During Measurement Period":
	( [Encounter: "Care Services in Long-Term Residential Facility"]
		union [Encounter: "Nursing Facility Visit"] ) LongTermFacilityEncounter
		where LongTermFacilityEncounter.period overlaps "Measurement Period"
		return LongTermFacilityEncounter.period
			intersect "Measurement Period"

define "Inpatient Encounter with Advanced Illness":
	[Encounter: "Acute Inpatient"] InpatientEncounter
		with "Advanced Illness Diagnoses" AdvancedIllnessDiagnosis
            such that exists (
                InpatientEncounter.diagnosis.condition Condition
                    where EndsWith(Condition.reference, AdvancedIllnessDiagnosis.id)
            )
			and InpatientEncounter.period starts 2 years or less before
			end of "Measurement Period"

define "Dementia Medications In Year Before or During Measurement Period":
	["MedicationDispense": "Dementia Medications"] DementiaMed
		where DementiaMed.whenHandedOver as dateTime during day of Interval[
            ( start of "Measurement Period" - 1 year ), end of "Measurement Period"
        ]

define "Has Criteria Indicating Frailty":
	exists ( [DeviceRequest: "Frailty Device"] FrailtyDeviceOrder
			where FrailtyDeviceOrder.authoredOn during day of "Measurement Period"
	)
		or exists ( [DeviceUseStatement: "Frailty Device"] FrailtyDeviceUse
				where FrailtyDeviceUse.timing as Period overlaps "Measurement Period"
                    or FrailtyDeviceUse.timing as dateTime during day of "Measurement Period"
		)
		or exists ( [Condition: "Frailty Diagnosis"] FrailtyDiagnosis
				where FrailtyDiagnosis.onset as Period overlaps "Measurement Period"
                    or FrailtyDiagnosis.onset as dateTime during day of "Measurement Period"
		)
		or exists ( [Encounter: "Frailty Encounter"] FrailtyEncounter
				where FrailtyEncounter.period overlaps "Measurement Period"
		)
		or exists ( [Observation: "Frailty Symptom"] FrailtySymptomObservation
				where FrailtySymptomObservation.effective as Period overlaps "Measurement Period"
                    or FrailtySymptomObservation.effective as dateTime during day of "Measurement Period"
		)

define "Advanced Illness and Frailty Exclusion Including Over Age 80":
	//If the measure includes populations age 80 and older, then use this logic:
	(
        Global."CalendarAgeInYearsAt"(FHIRHelpers.ToDate(Patient.birthDate), start of "Measurement Period")in Interval[66, 80]
            and "Has Criteria Indicating Frailty"
            and ( Count("Outpatient Encounters with Advanced Illness")>= 2
                or exists ( "Inpatient Encounter with Advanced Illness" )
                or exists "Dementia Medications In Year Before or During Measurement Period"
            )
	)
		or (
            Global."CalendarAgeInYearsAt"(FHIRHelpers.ToDate(Patient.birthDate), start of "Measurement Period")>= 81
			    and "Has Criteria Indicating Frailty"
		)

define "Advanced Illness and Frailty Exclusion Including Under Age 80":
	//If the measure does NOT include populations age 80 and older, then use this logic:
	Global."CalendarAgeInYearsAt"(FHIRHelpers.ToDate(Patient.birthDate), start of "Measurement Period")>= 65
        and "Has Criteria Indicating Frailty"
        and ( Count("Outpatient Encounters with Advanced Illness")>= 2
            or exists ( "Inpatient Encounter with Advanced Illness" )
            or exists "Dementia Medications In Year Before or During Measurement Period"
        )

define "Has Spent More Than 90 Days in Long Term Care":
	"Days Spent in Long Term Care During Measurement Period" > 90

define "Days Spent in Long Term Care During Measurement Period":
	"CumulativeDays"("Long Term Care Periods During Measurement Period")

define function "CumulativeDays"(Intervals List<Interval<DateTime>> ):
	Sum((collapse Intervals)CollapsedInterval
			return all duration in days of CollapsedInterval
	)
