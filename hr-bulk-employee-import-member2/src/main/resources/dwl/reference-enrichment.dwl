
%dw 2.0
output application/json

var validEmployees = payload.validEmployees default []
var previousRejections = payload.rejectedEmployees default []

var enrichedResults = validEmployees map (emp) -> do {
    var departmentKey =
        Mule::p("department." ++ (emp.departmentCode default ""))

    var locationKey =
        Mule::p("location." ++ (emp.locationCode default ""))

    var grade =
        Mule::p("designation." ++ (emp.designation default ""))

    var errors = [
        if (departmentKey == null)
            "Unknown department code: " ++ (emp.departmentCode default "missing")
        else null,

        if (locationKey == null)
            "Unknown location code: " ++ (emp.locationCode default "missing")
        else null,

        if (grade == null)
            "Unknown designation: " ++ (emp.designation default "missing")
        else null
    ] filter ($ != null)

    ---
    {
        employee: emp ++ {
            departmentKey: departmentKey,
            locationKey: locationKey,
            grade: grade
        },
        isValid: isEmpty(errors),
        rejectionCode:
            if (isEmpty(errors)) null else "REFERENCE_NOT_FOUND",
        rejectionReason:
            if (isEmpty(errors)) null else errors joinBy "; "
    }
}

var newlyRejected =
    enrichedResults filter (!$.isValid)

var accepted =
    enrichedResults filter $.isValid

var newRejections =
    newlyRejected map {
        employee: $.employee,
        rejectionCode: $.rejectionCode,
        rejectionReason: $.rejectionReason
    }

---
{
    totalCount: sizeOf(accepted) + sizeOf(newlyRejected) + sizeOf(previousRejections),
    validCount: sizeOf(accepted),
    rejectedCount: sizeOf(newlyRejected) + sizeOf(previousRejections),

    validEmployees:
        accepted map $.employee,

    rejectedEmployees:
        previousRejections ++ newRejections
}
