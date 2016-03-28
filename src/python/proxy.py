import requests
import json

class JsonRpcProxy:
    """
        Wraps function calls to JSON-RPC calls to the host
    """

    def __init__(self, host):
        self.host = host

    def __getattr__(self, *args):
        host = self.host
        method = args[0]
        def jsonRpcFunction(**kwargs):
            jsonRpcRequest = {
                'jsonrpc': '2.0',
                'id': 1,
                'method': method,
                'params': {}
            }

            files = {}

            for key, value in kwargs.iteritems():
                if isinstance(value, file):
                    files[key] = value
                else:
                    jsonRpcRequest['params'][key] = value

            response = None
            if files:
                #Add the JSON-RPC message to the multipart message
                #WARNING! This is not yet supported by the server JSON-RPC handlers in this library
                fileParts = {'jsonrpc': ('jsonrpc', json.dumps(jsonRpcRequest))}
                for key, value in files.iteritems():
                    fileParts[key] = (key, value, 'application/octet-stream')
                response = requests.post(host, files=fileParts)
            else:
                headers = {'Content-Type': 'application/json-rpc'}
                response = requests.post(host, headers=headers, data=json.dumps(jsonRpcRequest))

            responseJson = response.json()
            if 'error' in responseJson:
                raise ValueError(responseJson['error'])
            return responseJson['result']
        return jsonRpcFunction

if __name__ == '__main__':
    import sys
    if len(sys.argv) <= 2:
        print('    Creates JSON-RPC method calls from arguments:')
        print('        <HOST> <METHOD> [arg1=val1] [arg2=val2] ... [argn=valn]')
        print('        Returns: JSON-RPC method call result, or throws an error')
        print('')
        print('        For example:')
        print('            proxy.py http://localhost:9000 test echo=foo')
    else:
        host = sys.argv[1]
        method = sys.argv[2]
        args = {}
        for arg in sys.argv[3:]:
            tokens = arg.split('=')
            args[tokens[0]] = tokens[1]
        proxy = JsonRpcProxy(host)
        methodToCall = getattr(proxy, method)
        print(methodToCall(**args))
