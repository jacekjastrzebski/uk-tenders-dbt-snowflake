> Source: <https://www.find-tender.service.gov.uk/apidocumentation/1.0/GET-ocdsReleasePackages>  
> Downloaded: 2026-10-06. Crown copyright, Open Government Licence v3.0.

# GET /api/{version}/ocdsReleasePackages

## Description

This service retrieves Find a Tender notice data as an Open Contracting Data Standard (OCDS) release package.

## Request Information

Requests can be filtered to a notice or procurement process by appending an ID to the URI: 

  * Notice IDs are in the form nnnnnn-yyyy where nnnnnn is a zero-padded decimal number and yyyy is the publication year.
  * Procurement process IDs (ocids) are in the form ocds-h6vhtk-hhhhhh, where hhhhhh is a zero-padded hexadecimal number.

### URI Parameters

Name| Description| Type| Mandatory| Format| Min value| Max value| Max length| Example  
---|---|---|---|---|---|---|---|---  
limit | Limit the number of results (default = 100) | integer | false | [0-9]* | 1 | 100 | n/a | 10  
cursor | Where more results are available, please use this token to get the next set of results | string | false | [A-Za-z0-9=]* | n/a | n/a | 300 | MTAwM==  
updatedFrom | Earliest date and time record was last updated | date | false | YYYY-MM-DDTHH:MM:SS | n/a | n/a | 19 | 2026-09-26T19:03:12  
updatedTo | Latest date and time record was last updated | date | false | YYYY-MM-DDTHH:MM:SS | n/a | n/a | 19 | 2026-10-06T19:03:12  
stages | Stage of the contracting process | string | false | planning,tender,award | n/a | n/a | n/a | tender  
  
### Body Parameters

None.

### Request Formats

#### application/x-www-form-urlencoded

**Example of filtering by date**
    
    
    /api/1.0/ocdsReleasePackages?updatedFrom=2020-12-31T23:00:00&updatedTo=2021-01-07T22:59:59
    		

#### application/x-www-form-urlencoded

**Example of filtering by ocid**
    
    
    /api/1.0/ocdsReleasePackages/ocds-h6vhtk-0001b4
    		

#### application/x-www-form-urlencoded

**Example of filtering by notice ID**
    
    
    /api/1.0/ocdsReleasePackages/000001-2021
    		

## Response Information

### Resource Description

An [OCDS release package](https://standard.open-contracting.org/latest/en/schema/release_package/) containing an array of releases. Release IDs are unique within a procurement process (ocid). Party (buyer or supplier) IDs are unique within a release. Notices are converted to OCDS format using the [field mapping defined by the Open Contracting Partnership](https://standard.open-contracting.org/profiles/eu/master/en/).

### Response Formats

#### HTTP response status code: 200

When there is a successful response the following parameters are returned:

#### application/json, text/json

**Sample:**
    
    
     {
        "uri": "https://www-integration.find-tender.service.gov.uk/api/1.0/ocdsReleasePackages/001060-2020",
        "version": "1.1",
        "extensions": [
            "https://standard.open-contracting.org/profiles/eu/master/en/extension.json"
        ],
        "publishedDate": "2020-12-09T09:38:51Z",
        "publisher": {
            "name": "Cabinet Office",
            "scheme": "GB-GOR",
            "uid": "D2",
            "uri": "https://www.gov.uk/government/organisations/cabinet-office"
        },
        "license": "http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
        "publicationPolicy": "https://www.gov.uk/government/publications/open-contracting",
        "releases": [
            {
                "ocid": "ocds-h6vhtk-0026ef-integration",
                "id": "001060-2020",
                "date": "2020-12-08T11:07:45Z",
                "tag": [
                    "planning"
                ],
                "description": "Sample additional information",
                "initiationType": "tender",
                "tender": {
                    "id": "123456",
                    "legalBasis": {
                        "id": "32014L0024",
                        "scheme": "CELEX"
                    },
                    "title": "Sample title",
                    "status": "planned",
                    "classification": {
                        "scheme": "CPV",
                        "id": "03000000",
                        "description": "Agricultural, farming, fishing, forestry and related products"
                    },
                    "mainProcurementCategory": "goods",
                    "description": "Sample short description",
                    "value": {
                        "amount": 123,
                        "currency": "GBP"
                    },
                    "lots": [
                        {
                            "id": "1",
                            "description": "Sample description of the procurement. Additional information: Sample additional information",
                            "awardCriteria": {
                                "criteria": [
                                    {
                                        "type": "price"
                                    }
                                ]
                            },
                            "value": {
                                "amount": 123,
                                "currency": "GBP"
                            },
                            "contractPeriod": {
                                "durationInDays": 30
                            },
                            "hasRenewal": true,
                            "renewal": {
                                "description": "Sample renewals description"
                            },
                            "submissionTerms": {
                                "variantPolicy": "allowed"
                            },
                            "hasOptions": true,
                            "options": {
                                "description": "Sample description of options"
                            },
                            "status": "planned"
                        }
                    ],
                    "items": [
                        {
                            "id": "1",
                            "additionalClassifications": [
                                {
                                    "scheme": "CPV",
                                    "id": "03000000",
                                    "description": "Agricultural, farming, fishing, forestry and related products"
                                }
                            ],
                            "deliveryAddresses": [
                                {
                                    "region": "UK"
                                }
                            ],
                            "relatedLot": "1"
                        }
                    ],
                    "communication": {
                        "futureNoticeDate": "2020-12-30T00:00:00Z",
                        "atypicalToolUrl": "https://www.SampleURL.com/"
                    },
                    "submissionMethod": [
                        "electronicSubmission",
                        "written"
                    ],
                    "submissionMethodDetails": "https://www.SampleURL.com",
                    "selectionCriteria": {
                        "criteria": [
                            {
                                "type": "suitability",
                                "description": "Sample description of conditions",
                                "appliesTo": "supplier"
                            }
                        ]
                    },
                    "documents": [
                        {
                            "documentType": "economicSelectionCriteria",
                            "id": "economic"
                        },
                        {
                            "documentType": "technicalSelectionCriteria",
                            "id": "technical"
                        }
                    ],
                    "otherRequirements": {
                        "reservedParticipation": [
                            "shelteredWorkshop"
                        ],
                        "requiresStaffNamesAndQualifications": true
                    },
                    "contractTerms": {
                        "reservedExecution": true,
                        "performanceTerms": "Sample contract performance conditions",
                        "hasElectronicOrdering": true,
                        "electronicInvoicingPolicy": "allowed",
                        "hasElectronicPayment": true
                    },
                    "techniques": {
                        "hasFrameworkAgreement": true,
                        "frameworkAgreement": {
                            "maximumParticipants": 1,
                            "periodRationale": "Sample justification"
                        },
                        "hasElectronicAuction": true,
                        "electronicAuction": {
                            "description": "Sample additional information about electronic auction"
                        }
                    },
                    "coveredBy": [
                        "GPA"
                    ],
                    "awardPeriod": {
                        "startDate": "2020-12-31T00:00:00Z"
                    },
                    "reviewDetails": "Sample review procedure"
                },
                "parties": [
                    {
                        "name": "Buyer name",
                        "id": "1",
                        "identifier": {
                            "legalName": "Buyer name"
                        },
                        "address": {
                            "streetAddress": "Buyer address",
                            "locality": "Buyer town",
                            "region": "UK",
                            "postalCode": "A23JD",
                            "countryName": "United Kingdom"
                        },
                        "contactPoint": {
                            "name": "Contact person name",
                            "telephone": "+44 1234562121",
                            "email": "ContactEmail@sample.com",
                            "faxNumber": "+44 1234567890",
                            "url": "https://www.SampleURL.com/"
                        },
                        "roles": [
                            "buyer",
                            "centralPurchasingBody"
                        ],
                        "details": {
                            "url": "https://www.MainSampleAddress.com/",
                            "buyerProfile": "https://www.BuyerSampleAddress.com/",
                            "classifications": [
                                {
                                    "scheme": "TED_CA_TYPE",
                                    "id": "MINISTRY",
                                    "description": "Ministry or any other national or federal authority, including their regional or local subdivisions"
                                },
                                {
                                    "scheme": "COFOG",
                                    "id": "01",
                                    "description": "General public services"
                                }
                            ]
                        }
                    }
                ],
                "buyer": {
                    "id": "1",
                    "name": "Buyer name"
                },
                "language": "en"
            }
        ]
    }			

#### HTTP response status code: 400

When the wrong parameter name is provided.

#### application/json, text/json

**Sample:**
    
    
    {
        "timestamp": "2026-10-06T19:03:12",
        "status": 400,
        "error": "Bad Request",
        "message": "Request parameters unknown",
        "path": "/api/1.0/ocdsReleasePackages",
        "exception": "Request parameter 'statuses' is not recognised, allowed parameters are: stages, limit, cursor, updatedFrom, updatedTo"
    }			

#### HTTP response status code: 429

When the user has submitted too many requests, no further requests should be made until after the number of seconds specified in the Retry-After header value

#### text/plain

**Sample:**

**Response headers include:**

Retry-After: 11

**Body:**

Too Many Requests

#### HTTP response status code: 503

When the service is unavailable to respond, no further requests should be made until after the number of seconds specified in the Retry-After header value

#### text/plain

**Sample:**

**Response headers include:**

Retry-After: 11

**Body:**

Service Unavailaible
