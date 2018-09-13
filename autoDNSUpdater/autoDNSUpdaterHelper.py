#author: Ibrahim Khan

import sys
import requests
import json
import configparser
from pathlib import Path

#generates config file 'autoDNSUpdaterConfig.ini' with null values. 
#Terminates if file already exists.
def genConfig():
    fileName = 'autoDNSUpdaterConfig.ini'
    if Path(fileName).exists():
        print('File ' + fileName + ' exists already. Delete first to create a new file.', file=sys.stderr)
        sys.exit(1)
    config = configparser.ConfigParser()
    config['CFD_CONFIG'] = {'x-auth-key':'', 'x-auth-email':'','zone-id':''}
    with open(fileName, 'w') as configFile:
        config.write(configFile)
    return True

#loads config from 'cfdConfig.ini'.
#Terminates on no file, or missing or empty values.
def loadConfig():
    fileName = 'cfdConfig.ini'
    if not Path(fileName).exists():
        configError('File '+ fileName + ' does not exist')
    config = configparser.ConfigParser()
    config.read('cfdConfig.ini')
    rParams = {}
    if 'CFD_CONFIG' in config:
        rParams = dict(config['CFD_CONFIG'])
        if all (key in rParams for key in ['x-auth-key', 'x-auth-email', 'zone-id']):
            if any (val == '' for val in rParams.values()):
                configError('null value')
                return
            else:
                return rParams
        else:
            configError('Missing key')
    configError('No CFD_CONFIG section')
    return

#writes config error to stderr and terminates
def configError(errorStr):
    print('''Invalid config file ''' + errorStr + '''. Run genConfig to generate blank config file 'cfdConfig.ini' \n''', file=sys.stderr)
    sys.exit(1)
    return

#returns header dict of key val pairs given configDict
def getHeadersDict(conDict):
    headersArray = {}
    headersArray['X-Auth-Key'] = conDict['x-auth-key']
    headersArray['X-Auth-Email'] = conDict['x-auth-email']
    headersArray['Content-Type'] = 'application/json'
    return headersArray

def storeIP(ipStr):
    fileName = 'storedIP.txt'
    fw = open(fileName, 'w')
    print(ipStr, file=fw)
    fw.close()
    return

def getStoredIP():
    fileName = 'storedIP.txt'
    fr = open(fileName, 'rU')
    ipStr = fr.read()
    fr.close()
    ipStr = ipStr.strip()
    return ipStr

#returns current external IP address
def getActualIP():
    actualIP = ''
    urlStr = 'https://checkip.amazonaws.com'
    with requests.get(urlStr) as f:
        actualIP = f.text.strip()
    return actualIP

#returns current targetIP of records given array of records.
#Terminates if not all records consistent.
def getTargetIP(recordsArray):
    targetIP = ''
    for record in recordsArray:
        if targetIP == '':
            targetIP = record['content']
        elif targetIP != record['content']:
            print('inconsistent target IPs\n' + 'expected: ' + targetIP + '\n' + 'read: ' + record['content'] + '\n', file=sys.stderr)
            sys.exit(1)
    return targetIP

#Returns array of records from cloudflare API given zone ID
def getRecordsArray():
    resp = cfgGet('zones/' + loadConfig()['zone-id'] + '/dns_records', {'type':'A'}) 
    return resp['result']

#checks if each record needs updating, and calls update method accordingly
def updateRecordsIP(recordsArray, newIP):
    for recordDict in recordsArray:
        if recordDict['content'] != newIP:
            setRecordIP(recordDict, newIP)
    return

#updates record to point to IP
def setRecordIP(recordDict, newIP):
    data = {}
    data['type'] = recordDict['type']
    data['name'] = recordDict['name']
    data['content'] = newIP

    print('UPDATING RECORD: ', recordDict['id'])
    print('FROM IP: ', recordDict['content'])
    print('TO IP: ', newIP)
    print()
    print('REQUEST RESULT')
    print(cfgPut('zones/' + recordDict['zone_id'] + '/dns_records/' + recordDict['id'], data))
    print()
    return False

def validate():
    changed = False
    records = getRecordsArray()
    currentTarget = getTargetIP(records)
    actualIP = getActualIP()
    if actualIP != currentTarget:
        print('UPDATING RECORD IP ' + currentTarget + ' WITH NEW IP ' + actualIP)
        updateRecordsIP(records, actualIP)
        changed = True
    return changed

def cfgGet(requestStr, params):
    jResp = {}
    metaData = cfgRequestMeta(requestStr)
    url = metaData[0]
    headers = metaData[1]
    
    with requests.get(url, headers=headers, params=params) as r:
        jResp = r.json()
    
    return jResp

def cfgPut(requestStr, data):
    jResp = {}
    metaData = cfgRequestMeta(requestStr)
    url = metaData[0]
    headers = metaData[1]

    with requests.put(url, headers=headers, json=data) as r:
        jResp = r.json()
    return jResp

def cfgRequestMeta(requestStr):
    jResp = {}
    base = 'https://api.cloudflare.com/client/v4/'
    url = base + requestStr
    headers = getHeadersDict(loadConfig())
    
    return (url, headers)

    
if __name__ == '__main__':
    if len(sys.argv) == 1:
        validate()
    elif sys.argv[1] == '-o':
        createConfig()
        loadConfig(validate())
    else:
        print('usage: cfd.py [-o create blank config]')
        sys.exit(0)

