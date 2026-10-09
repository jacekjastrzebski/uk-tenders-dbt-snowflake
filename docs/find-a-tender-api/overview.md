> Source: <https://www.find-tender.service.gov.uk/Developer/Documentation>
> Downloaded: 2026-10-06. Crown copyright, Open Government Licence v3.0.

# Data and API documentation

## Data outputs

The UK is committed to [open contracting](https://www.gov.uk/government/publications/open-contracting). Notice data is available under the [Open Government Licence](http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

### OCDS API

You can download notices in Open Contracting Data Standard (OCDS) JSON format using our API. Notice fields are mapped to OCDS version 1.1.5 with extensions as [defined by the Open Contracting Partnership](https://standard.open-contracting.org/profiles/eu/master/en/).

  * [OCDS release package API](https://www.find-tender.service.gov.uk/apidocumentation/1.0/GET-ocdsReleasePackages)
  * [OCDS record package API](https://www.find-tender.service.gov.uk/apidocumentation/1.0/GET-ocdsRecordPackages)

### XML downloads

The same notice data is also available to download from the data.gov.uk website or using their API. Daily Zip files contain an XML file for each notice.

  * [View on data.gov.uk](https://data.gov.uk/search?q=%22UK+Public+Procurement+Notices%22&filters%5Bpublisher%5D=Crown+Commercial+Service&filters%5Btopic%5D=&filters%5Bformat%5D=&sort=recent)
  * [data.gov.uk API documentation](https://guidance.data.gov.uk/get_data/api_documentation/#api-documentation)
  * [Example API call](https://ckan.publishing.service.gov.uk/api/action/package_search?fq=name%3Auk-public-procurement-notices-january-2021)

### Publication XML schema downloads

New schema - may be used for notices published from 21 July 2022 (to be confirmed):

  * [R2.0.8.UK1.E01_002](https://www.find-tender.service.gov.uk/Home/Schema/XSD/R208/publication/UK1/E01_002) for defence forms F16, F17, F18 and F19
  * [R2.0.9.UK1.E01_002](https://www.find-tender.service.gov.uk/Home/Schema/XSD/R209/publication/UK1/E01_002) for all other forms

Current schema - may be used for notices published from 2 March 2021 to 20 July 2022 (to be confirmed):

  * [R2.0.8.S05.E01_002](https://www.find-tender.service.gov.uk/Home/Schema/XSD/R208/publication/S05/E01) for defence forms F16, F17, F18 and F19
  * [R2.0.9.S04.E01_002](https://www.find-tender.service.gov.uk/Home/Schema/XSD/R209/publication/S04/E01) for all other forms

Previous schema - may be used for notices published to 3 May 2021:

  * [R2.0.8.S04.E01_003](https://www.find-tender.service.gov.uk/Home/Schema/XSD/R208/publication/S04/E01) for defence forms F16, F17, F18 and F19
  * [R2.0.9.S03.E01_009](https://www.find-tender.service.gov.uk/Home/Schema/XSD/R209/publication/S03/E01) for all other forms

Note that from 2 March to 3 May 2021 notices may use either schema.

Find a Tender XML formats are based on those used by Tenders Electronic Daily (TED). See details of the [changes from TED and between versions on Find a Tender](https://www.find-tender.service.gov.uk/schemadocumentation/schema-changes).
