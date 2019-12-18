# Reports

Scripts used to provide report to cycloid.

# Contribution

Global functions are located under `source/common.sh`.
Please use the `generate.sh` script to update the `generated/*_report.sh` script

```
./generate.sh
```

# Details

* **worker_report.sh**: Get report from concourse worker
* **onprem_report.sh**: Get report from cycloid onprem setup


## worker_report.sh

**functions list**

|Name|Description|parameters|
|---|---|---|
|`agreement`|Cycloid information and question regarding sensitive datas.|`false`|


### Usage
```
curl -s https://raw.githubusercontent.com/cycloidio/cycloid-utils/report/report/generated/worker_report.sh | sudo bash
```


## onprem_report.sh

**functions list**

|Name|Description|parameters|
|---|---|---|
|`agreement`|Cycloid information and question regarding sensitive datas.|`false`|



### Usage
```
curl -s https://raw.githubusercontent.com/cycloidio/cycloid-utils/report/report/generated/onprem_report.sh | sudo bash
```
