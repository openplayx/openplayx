#!/usr/bin/env python3
"""Initialize only the disposable servers in this Compose project."""
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

JELLYFIN = 'http://127.0.0.1:18096'
PLEX = 'http://127.0.0.1:13240'
AUTH = 'MediaBrowser Client="OpenPlayX Test", Device="Integration", DeviceId="openplayx-test", Version="1"'


def call(base, path, method='GET', body=None, headers=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base + path, data=data, method=method,
        headers={'Content-Type': 'application/json', **(headers or {})})
    try:
        response = urllib.request.urlopen(req, timeout=10)
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors='replace')
        raise RuntimeError(f'{method} {path.split("?")[0]}: HTTP {error.code}: {detail[:1000]}') from None
    with response:
        payload = response.read()
        if not payload:
            return None
        return json.loads(payload)


def wait(base, path):
    for _ in range(60):
        try:
            return call(base, path)
        except (OSError, ValueError):
            time.sleep(1)
    raise RuntimeError(f'Service did not become ready: {base}')


def main():
    info = wait(JELLYFIN, '/System/Info/Public')
    if not info['StartupWizardCompleted']:
        call(JELLYFIN, '/Startup/Configuration', 'POST',
            {'UICulture': 'en-US', 'MetadataCountryCode': 'US', 'PreferredMetadataLanguage': 'en'})
        call(JELLYFIN, '/Startup/User')  # Creates the first user on a fresh server.
        call(JELLYFIN, '/Startup/User', 'POST', {'Name': 'openplayx', 'Password': 'test-only-password'})
        call(JELLYFIN, '/Startup/RemoteAccess', 'POST', {'EnableRemoteAccess': True, 'EnableAutomaticPortMapping': False})
        call(JELLYFIN, '/Startup/Complete', 'POST')
    auth = call(JELLYFIN, '/Users/AuthenticateByName', 'POST',
        {'Username': 'openplayx', 'Pw': 'test-only-password'}, {'Authorization': AUTH})
    token = auth['AccessToken']
    headers = {'Authorization': AUTH + ', Token="' + token + '"'}
    libraries = call(JELLYFIN, '/Library/VirtualFolders', headers=headers)
    if not libraries:
        call(JELLYFIN, '/Library/VirtualFolders?name=Test%20Videos&collectionType=homevideos&refreshLibrary=true', 'POST',
            {'LibraryOptions': {'PathInfos': [{'Path': '/media'}], 'EnableRealtimeMonitor': False,
                                'EnableInternetProviders': False, 'EnableAutomaticSeriesGrouping': False}}, headers)
    call(JELLYFIN, '/Library/Refresh', 'POST', headers=headers)
    for _ in range(60):
        items = call(JELLYFIN, f'/Users/{auth["User"]["Id"]}/Items?Recursive=true&IncludeItemTypes=Video,Movie', headers=headers)
        if items.get('Items'):
            break
        time.sleep(1)
    else:
        raise RuntimeError('Jellyfin media scan timed out')

    for _ in range(60):
        try:
            sections = call(PLEX, '/library/sections', headers={'Accept': 'application/json'})
            break
        except (OSError, ValueError):
            time.sleep(1)
    else:
        raise RuntimeError('Plex did not become ready')
    if not sections['MediaContainer'].get('Directory'):
        query = urllib.parse.urlencode({'name': 'Test Videos', 'type': 'movie',
            'agent': 'com.plexapp.agents.none', 'scanner': 'Plex Video Files Scanner',
            'language': 'xn', 'location': '/media'})
        call(PLEX, '/library/sections?' + query, 'POST', headers={'Accept': 'application/json'})
    sections = call(PLEX, '/library/sections', headers={'Accept': 'application/json'})
    section = sections['MediaContainer']['Directory'][0]['key']
    # refresh returns no JSON (usually HTTP 200 with an empty body).
    call(PLEX, f'/library/sections/{section}/refresh', headers={'Accept': 'application/json'})
    for _ in range(60):
        items = call(PLEX, f'/library/sections/{section}/all', headers={'Accept': 'application/json'})
        if items['MediaContainer'].get('Metadata'):
            break
        time.sleep(1)
    else:
        raise RuntimeError('Plex media scan timed out')
    defines = {'SOURCE_SERVICES': True, 'JELLYFIN_USER_ID': auth['User']['Id'], 'JELLYFIN_TOKEN': token}
    output = Path(__file__).with_name('defines.local.json')
    output.write_text(json.dumps(defines))
    output.chmod(0o600)
    print('Disposable SMB, Jellyfin and Plex services are ready. Test defines written to ' + str(output))


if __name__ == '__main__':
    main()
