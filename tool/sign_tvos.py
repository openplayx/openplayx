#!/usr/bin/env python3
"""Automatically archive/export a signed tvOS IPA using an ASC API bundle."""
import argparse,json,plistlib,re,subprocess,tempfile,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--credentials',required=True);p.add_argument('--output',required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[1];output=Path(a.output).resolve();output.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='openplayx-tvos-sign-') as temp:
 temp=Path(temp);temp.chmod(0o700)
 with zipfile.ZipFile(a.credentials) as z:
  for entry in z.infolist():
   if Path(entry.filename).is_absolute() or '..' in Path(entry.filename).parts:raise ValueError('Invalid credential bundle')
  z.extractall(temp)
 text=(temp/'asc-api-key.txt').read_text();key=re.search(r'KEY_ID=([A-Z0-9]{10})',text).group(1);issuer=re.search(r'[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}',text).group(0)
 auth=['-allowProvisioningUpdates','-authenticationKeyPath',str(temp/'asc-api-key.p8'),'-authenticationKeyID',key,'-authenticationKeyIssuerID',issuer]
 archive=root/'build/tvos-signing/Runner.xcarchive';opts=temp/'export.plist'
 opts.write_bytes(plistlib.dumps({'method':'app-store-connect','destination':'export','signingStyle':'automatic','teamID':'7UVYD43NRC','manageAppVersionAndBuildNumber':False,'uploadSymbols':True}))
 subprocess.run(['xcodebuild','-workspace','tvos/Runner.xcworkspace','-scheme','Runner','-configuration','Release','-destination','generic/platform=tvOS','-archivePath',str(archive),'-derivedDataPath','build/tvos-signing/DerivedData','archive','CODE_SIGNING_ALLOWED=NO',*auth],cwd=root,check=True)
 # Xcode emits a resource-only dylib for Sentry's static Swift package. Its
 # linker signature uses "Sentry", while Info.plist says "io.sentry.Sentry".
 # Export preserves that stale identifier in the designated requirement and
 # Apple's upload validator rejects it despite local deep verification passing.
 for framework in (archive/'Products/Applications/Runner.app/Frameworks').glob('*.framework'):
  info=plistlib.loads((framework/'Info.plist').read_bytes());identifier=info['CFBundleIdentifier']
  signature=subprocess.run(['codesign','-dvv',str(framework)],capture_output=True,text=True)
  match=re.search(r'^Identifier=(.+)$',signature.stderr,re.MULTILINE)
  if match and match.group(1)!=identifier:
   if 'Signature=adhoc' not in signature.stderr:raise RuntimeError(f'Unexpected signed framework identifier: {framework.name}')
   subprocess.run(['codesign','--force','--sign','-','--identifier',identifier,str(framework)],check=True)
 subprocess.run(['xcodebuild','-exportArchive','-archivePath',str(archive),'-exportPath',str(output),'-exportOptionsPlist',str(opts),*auth],cwd=root,check=True)
 with tempfile.TemporaryDirectory(prefix='openplayx-tvos-verify-') as verify:
  ipas=list(output.glob('*.ipa'))
  if len(ipas)!=1:raise RuntimeError('Expected exactly one signed IPA')
  with zipfile.ZipFile(ipas[0]) as z:z.extractall(verify)
  apps=list((Path(verify)/'Payload').glob('*.app'))
  if len(apps)!=1:raise RuntimeError('Invalid signed IPA Payload')
  subprocess.run(['codesign','--verify','--deep','--strict',str(apps[0])],check=True)
  identity=subprocess.run(['codesign','-dvv',str(apps[0])],capture_output=True,text=True,check=True).stderr
  if 'Authority=Apple Distribution:' not in identity:raise RuntimeError('Apple Distribution signature missing')
 print('Signed tvOS App Store export verified:',output)
