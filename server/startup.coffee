Meteor.startup ->
	# Patch any existing/new users up with an empty billing object
	cursor = Meteor.users.find()
	cursor.observe
		added: (usr) ->
			unless usr.billing
				Meteor.users.update _id: usr._id,
					$set: billing: {}