# HR Bulk Employee Import — Member 2
## Employee Validation & Reference Enrichment

**Platform:** MuleSoft Anypoint Studio  
**Mule Runtime:** 4.13.2 EE  
**Java:** 17  
**Module:** Employee Validation and Reference Enrichment

---

## 1. Module Overview

This module implements Member 2's responsibilities in the HR Bulk Employee Import solution.

It processes canonical employee records received from the file-intake module and performs two major operations:

1. **Employee Validation:** Validates mandatory employee fields, formats, dates, and business rules.
2. **Reference Enrichment:** Resolves department, location, and designation values using configured reference mappings and enriches valid employee records with their corresponding keys and grade.

The module separates valid records from rejected records and provides structured rejection codes and reasons.

### Position in the Overall Workflow

```text
Member 1: File Intake & CSV/XML Parsing
              |
              v
Member 2: Employee Validation
         & Reference Enrichment
              |
              v
Member 3: Duplicate Management,
         Manager Resolution & Threshold
              |
              v
Member 4: Database Batch Persistence
              |
              v
Member 5: Reject Files, Notifications
         & API Error Handling
```

Member 2 does not perform duplicate management, manager relationship resolution, or database persistence. Those responsibilities belong to the respective modules.

---

## 2. Responsibilities

### 2.1 Employee Validation

The employee-validation component checks each incoming employee record against mandatory-field, format, and business-rule requirements.

**A. Mandatory-field validation**

The following fields are checked for missing or blank values:

- `employeeId`
- `firstName`
- `lastName`
- `dateOfBirth`
- `dateOfJoining`
- `officialEmail`
- `mobile`
- `departmentCode`
- `designation`
- `locationCode`
- `employmentType`

Records with missing mandatory fields are rejected with the rejection code:

```text
MISSING_REQUIRED_FIELD
```

**B. Format validation**

The module validates:

| Field | Validation |
|---|---|
| Date of Birth | Expected format: `yyyy-MM-dd` |
| Date of Joining | Expected format: `yyyy-MM-dd` |
| Official Email | Email format validation |
| Mobile | Supports an optional country-code prefix and digits, spaces, or hyphens |

Records that fail these checks receive:

```text
INVALID_FORMAT
```

**C. Business-rule validation**

The implementation checks:

- Minimum employee age.
- Permitted future joining-date tolerance.

The current development configuration uses a minimum age of 18 years and a future joining-date tolerance of 7 days.

Records that violate these rules receive:

```text
BUSINESS_VALIDATION_FAILED
```

These values are configurable development defaults; the challenge specification does not prescribe the exact numerical age or date-tolerance values.

### 2.2 Reference Enrichment

After field validation, valid employee records are passed to the reference-enrichment component.

The component resolves:

| Employee field | Reference lookup | Enriched field |
|---|---|---|
| `departmentCode` | Department mapping | `departmentKey` |
| `locationCode` | Location mapping | `locationKey` |
| `designation` | Designation-to-grade mapping | `grade` |

If a reference value cannot be resolved, the employee is rejected with:

```text
REFERENCE_NOT_FOUND
```

The rejection reason includes the unresolved value. For example:

```text
Unknown department code: DEPT-XXX
```

This allows downstream modules to identify the exact reference-data issue.

---

## 3. Project Structure

The Member 2 project is organized as follows:

```text
hr-bulk-employee-import-member2/
│
├── src/
│   ├── main/
│   │   ├── mule/
│   │   │   └── member2-validation.xml
│   │   │
│   │   └── resources/
│   │       ├── dwl/
│   │       │   ├── employee-validation.dwl
│   │       │   └── reference-enrichment.dwl
│   │       │
│   │       └── config.properties
│   │
│   └── test/
│       └── munit/
│           └── (MUnit test suites, if present)
│
├── pom.xml
└── README.md
```

### File Responsibilities

| File | Purpose |
|---|---|
| `member2-validation.xml` | Defines the validation and enrichment subflows and orchestration flow |
| `employee-validation.dwl` | Implements employee field, format, and business-rule validation |
| `reference-enrichment.dwl` | Resolves department, location, and designation references |
| `config.properties` | Stores validation settings and illustrative reference mappings |
| `pom.xml` | Defines Mule application dependencies and build configuration |

---

## 4. Configuration

The module uses a properties file to keep validation settings and reference mappings configurable.

### Current `config.properties`

```properties
# Employee validation rules
validation.minimumAge=18
validation.futureJoiningDays=7

# Department reference mappings
department.DEPT-ENG=1
department.DEPT-FIN=2
department.DEPT-HR=3

# Location reference mappings
location.LOC-CHN-01=101
location.LOC-BLR-02=102

# Designation-to-grade mappings
designation.Senior\ Engineer=G5
designation.Engineer=G4
designation.Finance\ Analyst=G4
designation.HR\ Executive=G3
designation.Manager=G6
```

**Important:** The department and location keys and designation grades are illustrative mock mappings used for development. They are not actual database-generated keys.

The properties file must be loaded by Mule using the appropriate configuration declaration:

```xml
<configuration-properties file="config.properties"/>
```

The path must match the actual location of the file.

### Configuration Parameters

| Property | Purpose | Development value |
|---|---|---|
| `validation.minimumAge` | Minimum permitted employee age | 18 |
| `validation.futureJoiningDays` | Permitted future joining-date tolerance | 7 days |
| `department.*` | Department reference mappings | Illustrative |
| `location.*` | Location reference mappings | Illustrative |
| `designation.*` | Designation-to-grade mappings | Illustrative |

For the integrated application, the mock mappings should eventually be replaced with the authoritative reference data or database lookups agreed upon by the team.

---

## 5. Employee Validation Logic

The employee-validation logic is implemented in:

```text
employee-validation.dwl
```

The DataWeave script performs the following operations:

1. Reads the incoming employee payload.
2. Normalizes a single employee or an array into an employee collection.
3. Reads the minimum-age and future-date-tolerance configuration.
4. Validates mandatory fields.
5. Validates email, mobile, and date formats.
6. Calculates the employee's age.
7. Checks the joining date against the permitted future-date tolerance.
8. Creates a structured result for each employee.
9. Separates accepted and rejected employees.

### Validation Result Structure

Each employee is evaluated and assigned:

- `employee`
- `isValid`
- `rejectionCode`
- `rejectionReason`

The final output contains:

- `totalCount`
- `validCount`
- `rejectedCount`
- `validEmployees`
- `rejectedEmployees`

### Example Rejection

```json
{
  "employee": {
    "employeeId": "EMP10050",
    "firstName": "Sample",
    "lastName": "Employee",
    "officialEmail": "invalid-email"
  },
  "rejectionCode": "INVALID_FORMAT",
  "rejectionReason": "Invalid official email format"
}
```

The actual rejection reason may contain multiple validation errors joined together.

---

## 6. Reference Enrichment Logic

The reference-enrichment logic is implemented in:

```text
reference-enrichment.dwl
```

It receives the structured output of employee validation and processes only the valid employee records.

### Processing Steps

1. Extract `validEmployees` and previously rejected records.
2. Resolve each employee's department code.
3. Resolve each employee's location code.
4. Resolve the employee's designation and corresponding grade.
5. Add the resolved reference fields to the employee object.
6. Reject employees whose references cannot be resolved.
7. Merge newly rejected employees with the previously rejected employees.
8. Return the updated accepted/rejected counts and employee collections.

### Example: Successfully Enriched Employee

Input:

```json
{
  "employeeId": "EMP10041",
  "firstName": "Karthik",
  "lastName": "Subramanian",
  "departmentCode": "DEPT-ENG",
  "designation": "Senior Engineer",
  "locationCode": "LOC-CHN-01"
}
```

Illustrative enriched output:

```json
{
  "employeeId": "EMP10041",
  "firstName": "Karthik",
  "lastName": "Subramanian",
  "departmentCode": "DEPT-ENG",
  "designation": "Senior Engineer",
  "locationCode": "LOC-CHN-01",
  "departmentKey": "1",
  "locationKey": "101",
  "grade": "G5"
}
```

The keys shown above come from the development properties file and are illustrative.

### Example: Unresolved Reference

Input:

```json
{
  "employeeId": "EMP10045",
  "departmentCode": "DEPT-XXX",
  "designation": "Manager",
  "locationCode": "LOC-CHN-01"
}
```

Rejection:

```json
{
  "rejectionCode": "REFERENCE_NOT_FOUND",
  "rejectionReason": "Unknown department code: DEPT-XXX"
}
```

The employee is not included in the enriched accepted-record collection.

---

## 7. Mule Flow Architecture

The Mule orchestration is defined in:

```text
member2-validation.xml
```

It contains the following subflows:

| Flow/Subflow | Responsibility |
|---|---|
| `employee-validation-subflow` | Invokes the employee-validation DataWeave script |
| `reference-enrichment-subflow` | Invokes the reference-enrichment DataWeave script |
| `member2-validation-pipeline` | Coordinates both processing stages |

### Processing Sequence

```text
Canonical Employee Payload
            |
            v
employee-validation-subflow
            |
            v
Required Fields & Format Checks
            |
            v
Business Rule Validation
            |
            v
Valid / Rejected Records
            |
            v
reference-enrichment-subflow
            |
            v
Department / Location / Grade Lookup
            |
            v
Final Accepted / Rejected Records
            |
            v
Validation Summary Logger
```

The main orchestration flow is named:

```text
member2-validation-pipeline
```

---

## 8. Running in Anypoint Studio

1. Open Anypoint Studio.
2. Import or open `hr-bulk-employee-import-member2`.
3. Confirm Mule Runtime 4.13.2 EE and Java 17.
4. Check that the project dependencies in `pom.xml` resolve.
5. Verify that `config.properties` exists in the configured resources directory.
6. Verify that the Mule XML loads the properties file.
7. Open `member2-validation.xml`.
8. Run the Mule application.
9. Invoke `member2-validation-pipeline` with a canonical employee payload.
10. Inspect the output and logs for validation counts, accepted records, rejected records, and enrichment results.

The project also used a temporary scheduler-based test flow to supply sample employee records during development. That flow is only a test harness and should be removed before final integration if it is no longer needed.

---

## 9. Integration with Other Members

Member 2 is the second processing stage in the overall solution.

### Upstream: Member 1

Member 1 provides:

- Parsed CSV/XML employee records.
- Canonical employee field names.
- A collection of employee records.

The integration must ensure that Member 1's output is mapped to the payload structure expected by `employee-validation.dwl`.

### Downstream: Member 3

Member 3 receives the validated and reference-enriched employee records.

Its responsibilities include:

- Duplicate employee ID/email handling.
- Manager resolution.
- Rejection-threshold validation.

Manager resolution remains a Member 3 responsibility.

### Downstream: Member 4

Member 4 receives the accepted records eligible for persistence.

The illustrative reference keys in the current properties file must be replaced or reconciled with the authoritative database keys before production persistence.

### Downstream: Member 5

Member 5 needs access to rejected records and their rejection codes/reasons so it can generate rejection output and notifications.

### Integration Checklist

- Confirm the canonical input schema from Member 1.
- Ensure the payload passed into Member 2 is an employee array.
- Preserve any rejections already generated by Member 1.
- Confirm that Member 2 returns both accepted and rejected employee collections.
- Preserve rejection reasons and codes for Member 5.
- Confirm Member 3 receives the expected accepted employee collection.
- Replace mock reference mappings with the team's agreed reference-data source.
- Ensure all modules use consistent field names and count semantics.

---

## 10. Troubleshooting

| Issue | What to check |
|---|---|
| `try` reference cannot be resolved | Ensure the DataWeave script imports `try` from `dw::Runtime` |
| Configuration property returns null | Check the properties-file path and configuration-properties declaration |
| Designation mapping fails | Verify the property key, especially escaped spaces in designation names |
| Department is unexpectedly rejected | Check the department code and configured mapping |
| Location is unexpectedly rejected | Check the location code and configured mapping |
| Date validation fails | Confirm the input date uses `yyyy-MM-dd` |
| Mobile validation fails | Check the input against the configured mobile-number pattern |
| Flow reference cannot be resolved | Confirm the subflow names match the XML declarations |
| Mule XML fails to parse | Check namespace declarations, schema locations, and XML syntax |

---

## 11. Scope and Ownership

### Included in Member 2

- Mandatory employee-field validation.
- Date-format validation.
- Email-format validation.
- Mobile-format validation.
- Minimum-age validation.
- Future joining-date tolerance validation.
- Department reference enrichment.
- Location reference enrichment.
- Designation-to-grade enrichment.
- Structured rejection codes and reasons.
- Accepted and rejected employee separation.
- Validation and enrichment summary counts.

### Outside Member 2

- CSV/XML file listening and parsing.
- Duplicate employee ID/email handling.
- Manager resolution.
- Rejection-threshold decision.
- Database batch persistence.
- Reject-file generation and notification delivery.

These responsibilities belong to the other project members.

---

## 12. Development Status and Notes

The Member 2 Mule project was created and its main flows and DataWeave scripts were configured. The application successfully deployed in Anypoint Studio after resolving the DataWeave `try` import issue and Mule XML documentation namespace issue.

The latest available startup logs confirmed application deployment and DataWeave compilation. However, the captured logs did not yet show the scheduled test flow's final `TEST RESULT` output. Therefore, successful deployment and compilation should not be confused with a fully verified end-to-end test run.

Before final demonstration:

- Run the pipeline with the challenge sample records.
- Confirm the expected unknown department `DEPT-XXX` is rejected.
- Confirm the other sample records resolve using the configured mock mappings.
- Confirm the final accepted/rejected counts.
- Confirm the temporary test scheduler has been removed or disabled.

The minimum age, future joining tolerance, and mock reference mappings are development configuration choices. They should be aligned with the team's final integration requirements.

---

## 13. Final Notes

Member 2 provides the validation and reference-enrichment layer between file intake and downstream employee processing.

The module is intended to be integrated into the team's main Mule application rather than deployed as a separate final production service.

For final integration, maintain a consistent canonical employee schema, preserve earlier rejection information, and replace illustrative reference mappings with the agreed authoritative source.
