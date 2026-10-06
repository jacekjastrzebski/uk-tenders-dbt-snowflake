> Source: <https://www.find-tender.service.gov.uk/apidocumentation/1.0/GET-ocdsRecordPackages>  
> Downloaded: 2026-10-06. Crown copyright, Open Government Licence v3.0.

# GET /api/{version}/ocdsRecordPackages

## Description

This service retrieves Find a Tender procurement data as an Open Contracting Data Standard (OCDS) record package.

## Request Information

Requests can be filtered to a procurement process by appending an ID to the URI: 

  * Procurement process IDs (ocids) are in the form ocds-h6vhtk-hhhhhh, where hhhhhh is a zero-padded hexadecimal number.

### URI Parameters

None.

### Body Parameters

None.

### Request Formats

#### application/x-www-form-urlencoded
    
    
    /api/1.0/ocdsRecordPackages/ocds-h6vhtk-000cb9

## Response Information

### Resource Description

An [OCDS record package](https://standard.open-contracting.org/latest/en/schema/record_package/) containing an array of records. Release IDs are unique within a procurement process (ocid). Party (buyer or supplier) IDs are unique within a release. Notices are converted to OCDS format using the [field mapping defined by the Open Contracting Partnership](https://standard.open-contracting.org/profiles/eu/master/en/).

### Response Formats

#### HTTP response status code: 200

When there is a successful response the following parameters are returned:

#### application/json, text/json

**Sample:**
    
    
     {
        "uri": "https://www-integration.find-tender.service.gov.uk/api/1.0/ocdsRecordPackages/ocds-h6vhtk-000cb9",
        "publisher": {
            "name": "Cabinet Office",
            "scheme": "GB-GOR",
            "uid": "D2",
            "uri": "https://www.gov.uk/government/organisations/cabinet-office"
        },
        "publishedDate": "2023-10-10T12:00:35+01:00",
        "license": "http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
        "publicationPolicy": "https://www.gov.uk/government/publications/open-contracting",
        "version": "1.1",
        "extensions": [
    		"https://standard.open-contracting.org/profiles/eu/latest/en/extension.json",
    		"https://raw.githubusercontent.com/open-contracting-extensions/ocds_amendment_rationale_classifications_extension/master/extension.json",
    		"https://raw.githubusercontent.com/open-contracting-extensions/ocds_budget_breakdown_extension/master/extension.json",
    		"https://raw.githubusercontent.com/open-contracting-extensions/ocds_contract_completion_extension/master/extension.json",
    		"https://raw.githubusercontent.com/open-contracting-extensions/ocds_documentation_extension/master/extension.json",
    		"https://raw.githubusercontent.com/open-contracting-extensions/ocds_pagination_extension/master/extension.json",
    		"https://raw.githubusercontent.com/open-contracting-extensions/ocds_suitability_extension/master/extension.json",
    		"https://raw.githubusercontent.com/portaledcahn/ocds_Links_extension/main/extension.json",
    		"https://raw.githubusercontent.com/cabinetoffice/ocds_uk_extension/main/extension.json"
        ],
        "packages": [
            "https://www-integration.find-tender.service.gov.uk/api/1.0/ocdsRecordPackages/ocds-h6vhtk-000cb9"
        ],
        "records": [
            {
                "ocid": "ocds-h6vhtk-000cb9",
                "releases": [
                    {
                        "ocid": "ocds-h6vhtk-000cb9",
                        "id": "001323-2023",
                        "date": "2023-10-10T11:50:18+01:00",
                        "tag": [
                            "planning"
                        ],
                        "initiationType": "tender",
                        "tender": {
                            "id": "ocds-h6vhtk-000cb9",
                            "legalBasis": {
                                "id": "32014L0024",
                                "scheme": "CELEX"
                            },
                            "title": "Object 1 sample title",
                            "status": "planned",
                            ...
                    },
                    {
                        "ocid": "ocds-h6vhtk-000cb9",
                        "id": "001324-2023",
                        "date": "2023-10-10T12:00:35+01:00",
                        "tag": [
                            "tender"
                        ],
                        "initiationType": "tender",
                        "tender": {
                            "id": "ocds-h6vhtk-000cb9",
                            "legalBasis": {
                                "id": "32014L0024",
                                "scheme": "CELEX"
                            },
                            "title": "Object 1 sample title",
                            "status": "active",
                            ...
                    }
                ],
                "compiledRelease": {
                    "tag": [
                        "compiled"
                    ],
                    "id": "ocds-h6vhtk-000cb9-2023-10-10T12:00:35+01:00",
                    "date": "2023-10-10T12:00:35+01:00",
                    "ocid": "ocds-h6vhtk-000cb9",
                    "initiationType": "tender",
                    "tender": {
                        "id": "ocds-h6vhtk-000cb9",
                        "legalBasis": {
                            "id": "32014L0024",
                            "scheme": "CELEX"
                        },
                        "title": "Object 1 sample title",
                        "status": "active",
                        ...
                },
                "versionedRelease": {
                    "ocid": "ocds-h6vhtk-000cb9",
                    "initiationType": [
                        {
                            "releaseID": "001323-2023",
                            "releaseDate": "2023-10-10T11:50:18+01:00",
                            "releaseTag": [
                                "planning"
                            ],
                            "value": "tender"
                        }
                    ],
                    "tender": {
                        "id": [
                            {
                                "releaseID": "001323-2023",
                                "releaseDate": "2023-10-10T11:50:18+01:00",
                                "releaseTag": [
                                    "planning"
                                ],
                                "value": "ocds-h6vhtk-000cb9"
                            }
                        ],
                        "legalBasis": {
                            "id": [
                                {
                                    "releaseID": "001323-2023",
                                    "releaseDate": "2023-10-10T11:50:18+01:00",
                                    "releaseTag": [
                                        "planning"
                                    ],
                                    "value": "32014L0024"
                                }
                            ],
                            "scheme": [
                                {
                                    "releaseID": "001323-2023",
                                    "releaseDate": "2023-10-10T11:50:18+01:00",
                                    "releaseTag": [
                                        "planning"
                                    ],
                                    "value": "CELEX"
                                }
                            ]
                        },
                        "title": [
                            {
                                "releaseID": "001323-2023",
                                "releaseDate": "2023-10-10T11:50:18+01:00",
                                "releaseTag": [
                                    "planning"
                                ],
                                "value": "Object 1 sample title"
                            }
                        ],
                        "status": [
                            {
                                "releaseID": "001323-2023",
                                "releaseDate": "2023-10-10T11:50:18+01:00",
                                "releaseTag": [
                                    "planning"
                                ],
                                "value": "planned"
                            },
                            {
                                "releaseID": "001324-2023",
                                "releaseDate": "2023-10-10T12:00:35+01:00",
                                "releaseTag": [
                                    "tender"
                                ],
                                "value": "active"
                            }
                        ],
                        ...
                }
            }
        ]
    }			

#### HTTP response status code: 404

In case a procurement could not be found with the specified ocid.

#### application/json, text/json

**Sample:**
    
    
    {
        "timestamp": "2026-10-06T19:03:12",
        "status": 404,
        "error": "Not found",
        "message": "",
        "path": "/api/1.0/ocdsRecordPackages",
        "exception": "'identifier' is not found"
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
