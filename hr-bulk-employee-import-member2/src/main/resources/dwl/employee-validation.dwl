%dw 2.0
import try from dw::Runtime
output application/json

var today = now() as Date
var minimumAge = (Mule::p("validation.minimumAge") default "18") as Number
var futureJoiningDays = (Mule::p("validation.futureJoiningDays") default "7") as Number

var employees = if (payload is Array) payload else [payload]

fun notBlank(value) =
    !isEmpty(trim((value default "") as String))

fun validEmail(value) =
    notBlank(value) and
    ((value as String) matches /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/)

fun validMobile(value) =
    notBlank(value) and
    ((value as String) matches /^\+?[0-9][0-9\- ]{8,15}$/)

fun parseDate(value) =
    if (!notBlank(value))
        { success: false }
    else
        try(() -> (value as String) as Date {format: "yyyy-MM-dd"})

var results = employees map (emp) -> do {
    var dobResult = parseDate(emp.dateOfBirth)
    var dojResult = parseDate(emp.dateOfJoining)

    var dobValid = dobResult.success default false
    var dojValid = dojResult.success default false

    var dob = if (dobValid) dobResult.result else null
    var doj = if (dojValid) dojResult.result else null

    var age = if (dobValid)
        (today.year - dob.year) -
        (if (
            today.month < dob.month or
            (today.month == dob.month and today.day < dob.day)
        ) 1 else 0)
        else 0

    var requiredErrors = [
        if (!notBlank(emp.employeeId)) "Employee ID is required" else null,
        if (!notBlank(emp.firstName)) "First name is required" else null,
        if (!notBlank(emp.lastName)) "Last name is required" else null,
        if (!notBlank(emp.dateOfBirth)) "Date of birth is required" else null,
        if (!notBlank(emp.dateOfJoining)) "Date of joining is required" else null,
        if (!notBlank(emp.officialEmail)) "Official email is required" else null,
        if (!notBlank(emp.mobile)) "Mobile number is required" else null,
        if (!notBlank(emp.departmentCode)) "Department code is required" else null,
        if (!notBlank(emp.designation)) "Designation is required" else null,
        if (!notBlank(emp.locationCode)) "Location code is required" else null,
        if (!notBlank(emp.employmentType)) "Employment type is required" else null
    ] filter ($ != null)

    var formatErrors = [
        if (notBlank(emp.dateOfBirth) and !dobValid)
            "Invalid date of birth. Expected yyyy-MM-dd" else null,
        if (notBlank(emp.dateOfJoining) and !dojValid)
            "Invalid date of joining. Expected yyyy-MM-dd" else null,
        if (notBlank(emp.officialEmail) and !validEmail(emp.officialEmail))
            "Invalid official email format" else null,
        if (notBlank(emp.mobile) and !validMobile(emp.mobile))
            "Invalid mobile number format" else null
    ] filter ($ != null)

    var businessErrors = [
        if (dobValid and age < minimumAge)
            "Employee must be at least " ++ (minimumAge as String) ++ " years old"
        else null,

        if (dojValid and doj > (today + ("P" ++ (futureJoiningDays as String) ++ "D") as Period))
            "Date of joining exceeds the permitted future-date tolerance"
        else null
    ] filter ($ != null)

    var errors = requiredErrors ++ formatErrors ++ businessErrors

    ---
    {
        employee: emp,
        isValid: isEmpty(errors),
        rejectionCode:
            if (isEmpty(errors)) null
            else if (!isEmpty(requiredErrors)) "MISSING_REQUIRED_FIELD"
            else if (!isEmpty(formatErrors)) "INVALID_FORMAT"
            else "BUSINESS_VALIDATION_FAILED",
        rejectionReason:
            if (isEmpty(errors)) null
            else errors joinBy "; "
    }
}
---
{
    totalCount: sizeOf(results),
    validCount: sizeOf(results filter ($.isValid == true)),
    rejectedCount: sizeOf(results filter ($.isValid == false)),

    validEmployees:
        (results filter ($.isValid == true)) map ((item) -> item.employee),

    rejectedEmployees:
        (results filter ($.isValid == false)) map ((item) -> {
            employee: item.employee,
            rejectionCode: item.rejectionCode,
            rejectionReason: item.rejectionReason
        })
}
