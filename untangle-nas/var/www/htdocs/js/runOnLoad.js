/*
 *
 * place any onload functions here .
 * always check the URL first to make
 * sure the right functions are called
 * on the right page
 *
 *
 */

function runOnLoad() {


    var url = window.location.pathname;

    // function list
   
    if (url == "/nas/admin/quota.html") {

        onloadQuota();

    }

    else if (url == "/nas/admin/quota_user.html") {

        onloadQuotaUser();

    }

    else if (url == "/nas/admin/quota_guest.html") {

        onloadQuotaGuest();

    }

    else if (url == "/nas/admin/services_ups.html") {

       onloadServicesUps();

    }

    else if (url == "/nas/admin/system_ups.html") {

        onloadGeneralUps();

    }

    else if (url == "/nas/admin/volumes_iscsi_targets.html") {

        onloadVolumesIscsiTargets();
    }

}
