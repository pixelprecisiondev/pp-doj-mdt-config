return {
    locale = 'en', -- available locales = https://pastebin.com/AzTKE9St

    homepage = {
        dispatchlimit = 10,
        maxSearchResults = 20
    },

    announcements = {
        minContentLength = 30
    },

    citizen = {
        licensePrefix = {
            ["driver"] = "Driver license",
            ['weapon'] = 'Weapon license',
            ['id'] = 'ID Card'
        }
    },

    forms = {
        autoSave = 10 * 60 * 1000,
        templates = {
            {
                fileName = 'Answer_to_Complaint.pdf',
                label = 'Answer to Complaint',
            },
            {
                fileName = 'Appearance.pdf',
                label = 'Appearance',
            },
            {
                fileName = 'Application_for_a_Search_Warrant.pdf',
                label = 'Application for a Search Warrant',
            },
            {
                fileName = 'Appointment_of_Counsel.pdf',
                label = 'Appointment of Counsel',
            },
            {
                fileName = 'Arrest_Warrant.pdf',
                label = 'Arrest Warrant',
            },
            {
                fileName = 'Civil_Complaint.pdf',
                label = 'Civil Complaint',
            },
            {
                fileName = 'Court_Response_to_Motion.pdf',
                label = 'Court Response to Motion',
            },
            {
                fileName = 'Criminal_Complaint.pdf',
                label = 'Criminal Complaint',
            },
            {
                fileName = 'Judgement_in_a_Civil_Action.pdf',
                label = 'Judgement in a Civil Action',
            },
            {
                fileName = 'Motion_for_Contempt.pdf',
                label = 'Motion for Contempt',
            },
            {
                fileName = 'Motion_for_Enlargement_of_Time.pdf',
                label = 'Motion for Enlargement of Time',
            },
            {
                fileName = 'Motion_to_Dismiss.pdf',
                label = 'Motion to Dismiss',
            },
            {
                fileName = 'Motion_to_Reconsider.pdf',
                label = 'Motion to Reconsider',
            },
            {
                fileName = 'Name_Change_Request.pdf',
                label = 'Name Change Request',
            },
            {
                fileName = 'Notice_of_Suit.pdf',
                label = 'Notice of Suit',
            },
            {
                fileName = 'Pre_Filing.pdf',
                label = 'Pre Filing',
            },
            {
                fileName = 'Response_to_Motion.pdf',
                label = 'Response to Motion',
            },
            {
                fileName = 'Search_and_Seizure_Warrant.pdf',
                label = 'Search and Seizure Warrant',
            },
            {
                fileName = 'Subpoena_Discovery.pdf',
                label = 'Subpoena Discovery',
            },
            {
                fileName = 'Subpoena_to_Testify_at_Criminal.pdf',
                label = 'Subpoena to Testify at Criminal',
            },
            {
                fileName = 'Subpoena_to_Testify.pdf',
                label = 'Subpoena to Testify',
            },
            {
                fileName = 'Substitution_of_Attorney.pdf',
                label = 'Substitution of Attorney',
            },
        }
    },

    formLimits = {
        ['notes'] = {
            title = { min = 5, max = 40},
            description = { min = 20, max = 300}
        },
    }
}