@description('Required. The name of the parent Azure Data Factory..')
param dataFactoryName string

var pipelineName = 'transform_csv' 
var sourceDataset = 'ms-cm-exports'
var sinkDataset = 'ingestion_csv'

resource dataFactoryRef 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' =  {
  name: pipelineName
  parent: dataFactoryRef
  properties: {
    activities: [
      {
        name: 'Convert CSV'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Delete Target'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          source: {
            type: 'DelimitedTextSource'
            storeSettings: {
              type: 'AzureBlobFSReadSettings'
              recursive: true
              enablePartitionDiscovery: false
            }
            formatSettings: {
              type: 'DelimitedTextReadSettings'
            }
          }
          sink: {
            type: 'DelimitedTextSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
            }
            formatSettings: {
              type: 'ParquetWriteSettings'
            }
          }
          enableStaging: false
          parallelCopies: 1
          validateDataConsistency: false
        }
        inputs: [
          {
            referenceName: sourceDataset
            type: 'DatasetReference'
            parameters: {
              folderName: {
                value: '@pipeline().parameters.folderName'
                type: 'Expression'
              }
              fileName: {
                value: '@pipeline().parameters.fileName'
                type: 'Expression'
              }
            }
          }
        ]
        outputs: [
          {
            referenceName: sinkDataset
            type: 'DatasetReference'
            parameters: {
              folderName: {
                value: '@variables(\'destinationFolder\')'
                type: 'Expression'
              }
              fileName: {
                value: '@variables(\'destinationFile\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      {
        name: 'Delete Target'
        type: 'Delete'
        dependsOn: [
          {
            activity: 'Set Destination Folder Name'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: sourceDataset
            type: 'DatasetReference'
            parameters: {
              folderName: {
                value: '@variables(\'destinationFolder\')'
                type: 'Expression'
              }
              fileName: {
                value: '@variables(\'destinationFile\')'
                type: 'Expression'
              }
            }
          }
          enableLogging: false
          storeSettings: {
            type: 'AzureBlobFSReadSettings'
            recursive: true
            enablePartitionDiscovery: false
          }
        }
      }
      {
        name: 'Delete CSV'
        type: 'Delete'
        dependsOn: [
          {
            activity: 'Convert CSV'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: sourceDataset
            type: 'DatasetReference'
            parameters: {
              folderName: {
                value: '@pipeline().parameters.folderName'
                type: 'Expression'
              }
              fileName: {
                value: '@pipeline().parameters.fileName'
                type: 'Expression'
              }
            }
          }
          enableLogging: false
          storeSettings: {
            type: 'AzureBlobFSReadSettings'
            recursive: true
            enablePartitionDiscovery: false
          }
        }
      }
      {
        name: 'Set Destination Folder Name'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Destination File Name'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'destinationFolder'
          value: {
            value: '@replace(concat(variables(\'scope\'),variables(\'date\'),\'/\',variables(\'metric\')),\'//\',\'/\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Destination File Name'
        description: ''
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Date'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'destinationFile'
          value: {
            value: '@replace(pipeline().parameters.fileName, \'.csv\', \'.csv.gz\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Date'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Metric'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'date'
          value: {
            value: '@split(pipeline().parameters.folderName, \'/\')[sub(length(split(pipeline().parameters.folderName, \'/\')), 3)]'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Metric'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Scope'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'metric'
          value: {
            value: '@first(split(split(pipeline().parameters.folderName, \'/\')[sub(length(split(pipeline().parameters.folderName, \'/\')), 4)], \'-\'))'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Scope'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Wait'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'scope'
          value: {
            value: '@replace(split(pipeline().parameters.folderName,split(pipeline().parameters.folderName, \'/\')[sub(length(split(pipeline().parameters.folderName, \'/\')), 4)])[0],\'ms-cm-exports\',\'ingestion\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Wait'
        type: 'Wait'
        dependsOn: []
        userProperties: []
        typeProperties: {
          waitTimeInSeconds: 60
        }
      }
    ]
    parameters: {
      fileName: {
        type: 'string'
      }
      folderName: {
        type: 'string'
      }
    }
    variables: {
      destinationFile: {
        type: 'String'
      }
      destinationFolder: {
        type: 'String'
      }
      scope: {
        type: 'String'
      }
      date: {
        type: 'String'
      }
      metric: {
        type: 'String'
      }
    }
    annotations: []
  }
}

@description('The name of the linked service.')
output name string = pipeline.name

@description('The resource ID of the linked service.')
output resourceId string = pipeline.id