"""Add test targets without regenerating or replacing the app's existing project."""
from pathlib import Path
import hashlib

project = Path('apps/ios/Exerly.xcodeproj/project.pbxproj')
s = project.read_text()
def key(name):
    return hashlib.sha256(('exerly.' + name).encode()).hexdigest()[:24].upper()
def entry(section, name, value):
    global s
    identifier = key(name)
    if identifier not in s:
        row = f'\t\t{identifier} /* {name} */ = {{ {value} }};\n'
        marker = f'/* End {section} section */'
        if marker in s:
            s = s.replace(marker, row + marker)
        else:
            s = s.replace('/* Begin PBXProject section */', f'/* Begin {section} section */\n{row}/* End {section} section */\n\n/* Begin PBXProject section */')
    return identifier

app = 'DDDDDDDDDDDDDDDDDDDDDDDD'
for name, ui in [('ExerlyTests', False), ('ExerlyUITests', True)]:
    source = 'ProductionUITests.swift' if ui else 'ProductionTests.swift'
    ref = entry('PBXFileReference', name + '.source', f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}/{source}; sourceTree = SOURCE_ROOT;')
    build = entry('PBXBuildFile', name + '.build', f'isa = PBXBuildFile; fileRef = {ref};')
    product = entry('PBXFileReference', name + '.product', f'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = {name}.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
    sources = entry('PBXSourcesBuildPhase', name + '.sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({build},); runOnlyForDeploymentPostprocessing = 0;')
    frameworks = entry('PBXFrameworksBuildPhase', name + '.frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    proxy = entry('PBXContainerItemProxy', name + '.proxy', f'isa = PBXContainerItemProxy; containerPortal = AAAAAAAAAAAAAAAAAAAAAAAA; proxyType = 1; remoteGlobalIDString = {app}; remoteInfo = Exerly;')
    dependency = entry('PBXTargetDependency', name + '.dependency', f'isa = PBXTargetDependency; target = {app}; targetProxy = {proxy};')
    configs = []
    for config in ['Debug', 'Release']:
        host = 'TEST_TARGET_NAME = Exerly;' if ui else 'BUNDLE_LOADER = "$(TEST_HOST)"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Exerly.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Exerly";'
        configs.append(entry('XCBuildConfiguration', name + '.' + config, f'isa = XCBuildConfiguration; buildSettings = {{ GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; PRODUCT_BUNDLE_IDENTIFIER = com.exerly.fitness.{name}; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; {host} }}; name = {config};'))
    configlist = entry('XCConfigurationList', name + '.configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    target = entry('PBXNativeTarget', name, f'isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = ({sources},{frameworks},); buildRules = (); dependencies = ({dependency},); name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.bundle.{"ui-testing" if ui else "unit-test"}";')
    marker = '\t\t\t\tDDDDDDDDDDDDDDDDDDDDDDDD /* Exerly */,\n'
    if f'\t\t\t\t{target},' not in s:
        s = s.replace(marker, marker + f'\t\t\t\t{target},\n')
    marker = '\t\t\t\tEEEEEEEEEEEEEEEEEEEEEEEE /* Exerly.app */,\n'
    if f'\t\t\t\t{product},' not in s:
        s = s.replace(marker, marker + f'\t\t\t\t{product},\n')
    marker = '\t\t\t\tCCCCCCCCCCCCCCCCCCCCCCCC /* Products */,\n'
    if f'\t\t\t\t{ref},' not in s:
        s = s.replace(marker, marker + f'\t\t\t\t{ref},\n')
project.write_text(s)

refs = lambda name, identifier, product: f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Exerly.xcodeproj"/>'
appref = refs('Exerly', app, 'Exerly.app')
testrefs = ''.join(f'<TestableReference skipped="NO">{refs(name, key(name), name + ".xctest")}</TestableReference>' for name in ['ExerlyTests', 'ExerlyUITests'])
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{testrefs}</Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
Path('apps/ios/Exerly.xcodeproj/xcshareddata/xcschemes/Exerly.xcscheme').write_text(scheme)
