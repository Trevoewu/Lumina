const gutendexSourceId = 'gutendex';
const librivoxSourceId = 'librivox';

const publicDomainRightsStatus = 'public_domain';
const userUploadedRightsStatus = 'user_uploaded';
const licensedRightsStatus = 'licensed';

bool canGenerateAudioForRights(String rightsStatus) {
  return rightsStatus == publicDomainRightsStatus ||
      rightsStatus == userUploadedRightsStatus ||
      rightsStatus == licensedRightsStatus;
}
