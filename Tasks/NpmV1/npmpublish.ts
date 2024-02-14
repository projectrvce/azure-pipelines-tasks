import * as tl from 'azure-pipelines-task-lib/task';

import { NpmTaskInput, RegistryLocation } from './constants';
import { INpmRegistry, NpmRegistry } from 'azure-pipelines-tasks-packaging-common/npm/npmregistry';
import { NpmToolRunner } from './npmtoolrunner';
import * as util from 'azure-pipelines-tasks-packaging-common/util';
import * as npmutil from 'azure-pipelines-tasks-packaging-common/npm/npmutil';
import * as npmrcparser from 'azure-pipelines-tasks-packaging-common/npm/npmrcparser';
import { PackagingLocation, getFeedRegistryUrl, RegistryType } from 'azure-pipelines-tasks-packaging-common/locationUtilities';
import * as os from 'os';

export async function run(packagingLocation: PackagingLocation): Promise<void> {
    const workingDir = tl.getInput(NpmTaskInput.WorkingDir) || process.cwd();
    const npmrc = npmutil.getTempNpmrcPath();
    const npmRegistry: INpmRegistry = await getPublishRegistry(packagingLocation);

    tl.debug(tl.loc('PublishRegistry', npmRegistry.url));
    npmutil.appendToNpmrc(npmrc, `registry=${npmRegistry.url}\n`);
    npmutil.appendToNpmrc(npmrc, `${npmRegistry.auth}\n`);

    // For publish, always override their project .npmrc
    const npm = new NpmToolRunner(workingDir, npmrc, true);
    npm.line('publish');

    npm.execSync();

    tl.rmRF(npmrc);
    tl.rmRF(util.getTempPath());
}

export async function getPublishRegistry(packagingLocation: PackagingLocation): Promise<INpmRegistry> {
    let npmRegistry: INpmRegistry;
    const registryLocation = tl.getInput(NpmTaskInput.PublishRegistry) || null;
    switch (registryLocation) {
        case RegistryLocation.Feed:
            tl.debug(tl.loc('PublishFeed'));
            const feed = util.getProjectAndFeedIdFromInputParam(NpmTaskInput.PublishFeed);
            npmRegistry = await getNpmRegistry(packagingLocation.DefaultPackagingUri, feed, false, true);
            break;
        case RegistryLocation.External:
            tl.debug(tl.loc('PublishExternal'));
            const endpointId = tl.getInput(NpmTaskInput.PublishEndpoint, true);
            npmRegistry = await NpmRegistry.FromServiceEndpoint(endpointId);
            break;
    }
    return npmRegistry;
}

async function getNpmRegistry(defaultPackagingUri: string, feed: any, authOnly?: boolean, useSession?: boolean) {
    const lineEnd = os.EOL;
    let url: string;
    let nerfed: string;
    let auth: string;
    let username: string;
    let email: string;
    let password64: string;
    let accessToken: string;

    url = npmrcparser.NormalizeRegistry( await getFeedRegistryUrl(defaultPackagingUri, RegistryType.npm, feed.feedId, feed.project, null, useSession));
    nerfed = util.toNerfDart(url);

    const apitoken = util.getAccessToken('publishEndpoint', 'publishFeed');
    // Azure DevOps does not support PATs+Bearer only JWTs+Bearer
    email = 'VssEmail';
    username = 'VssToken';
    password64 = Buffer.from(apitoken).toString('base64');
    tl.setSecret(password64);

    auth = nerfed + ':username=' + username + lineEnd;
    auth += nerfed + ':_password=' + password64 + lineEnd;
    auth += nerfed + ':email=' + email + lineEnd;

    return new NpmRegistry(url, auth, authOnly);
}