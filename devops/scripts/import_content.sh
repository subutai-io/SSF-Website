#!/bin/bash

now=$(date +"%Y-%m-%d")
wkdir=$(dirname $0)/../..


if [[ -z "$(which curl)" ]]; then
  echo Can not find curl on your PATH
  echo please run apt-get install curl
  exit 1
fi

if [[ -z "$(which jsonnet)" ]]; then
  echo Can not find jsonnet on your PATH
  echo Add to your path or clone, build, and install from
  echo https://github.com/google/jsonnet
  exit 1
fi

if [[ -z "$(which node)" ]] || [[ -z "$(which npm)" ]]; then
    echo Can not find nodeJS or npm on your PATH
    echo https://nodejs.org/
    exit 1
fi

if [[ -z "$(which $wkdir/node_modules/.bin/json2yaml)" ]]; then
    OUTUT="$(npm install json2yaml)"

    if [[ -n "$OUTPUT" ]] && [[ ! "$OUTPUT" =~ "npm ERR!" ]]; then
        echo $OUTPUT
        exit 2;
    fi
fi

if [[ -z "$(which $wkdir/node_modules/.bin/xml2json)" ]]; then
    OUTUT="$(npm install xml2json)"

    if [[ -n "$OUTPUT" ]] && [[ ! "$OUTPUT" =~ "npm ERR!" ]]; then
        echo $OUTPUT
        exit 2;
    fi
fi

DESCR_PATH="./../../../project-descriptors";

while [[ $# > 0 ]]
do
key="$1"

case $key in
    -p|--path)
    DESCR_PATH="$2"
    shift
    ;;
    *)
    # unknown option
    ;;
esac
shift
done

bash $DESCR_PATH/build.sh

projects_dir=$DESCR_PATH/projects
members_dir=$DESCR_PATH/generated/members

#bash $members_dir/generate.sh

for descriptor in `find $members_dir -type f -regex '.*\.json'`; do
  filename=$(basename $descriptor)
  key=${filename%.json}

  cn=$(node -pe 'JSON.parse(process.argv[1])["ldap-user"].cn' "$(cat $members_dir/$key.json)")
  uid=$(node -pe 'JSON.parse(process.argv[1])["ldap-user"].uid' "$(cat $members_dir/$key.json)")
  userActivity=$(curl -u dashbot:ghkf346LU538QZRD -X GET 'https://confluence.subutai.io/activity?maxResults=5&streams=user+IS+'$key'' -A 'ssf')
  echo $userActivity > $DESCR_PATH/userActivity.xml
  cat "$DESCR_PATH"/userActivity.xml | $wkdir/node_modules/.bin/xml2json > $DESCR_PATH/userActivity.json
  userActivity=$(cat "$DESCR_PATH"/userActivity.json)
  userProfile=$(curl -u dashbot:ghkf346LU538QZRD -X GET 'https://jira.subutai.io/rest/api/2/user?key='$key'' -A 'ssf')

  userAvatar=$(node -pe '
            var url = '"$userProfile"'.avatarUrls["48x48"];
            url;
           ')
  wget --user-agent="Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0" --http-user=dashbot --http-password=ghkf346LU538QZRD "$userAvatar" -O "$wkdir"/img/avatars/"$key".png

  userProfile=$(node -pe '
            var profile = {};
            var userProfile = {};
            if ('"$userProfile"'.key){
                profile.key='"$userProfile"'.key;
                profile.name='"$userProfile"'.name;
                profile.emailAddress='"$userProfile"'.emailAddress;
                profile.displayName='"$userProfile"'.displayName;
                var userActivity = [];
                var feed = '"$userActivity"'.feed;
                if (feed.entry){
                    for (var i=0; i<feed.entry.length; i++)
                    {
                        var activity = {};
                        activity.published=feed.entry[i].published;
                        activity.updates=feed.entry[i].updated;
                        activity.category=feed.entry[i].category;
                        activity.summary=feed.entry[i]["activity:object"];
                        userActivity.push(activity);
                    }
                    profile.userActivity = userActivity;
                }
                else {
                    profile.userActivity = userActivity;
                }

                userProfile.userProfile = profile;
                JSON.stringify(userProfile);
            }
            else {
                JSON.stringify(userProfile);
            }
           ')
  echo $userProfile > $DESCR_PATH/userProfile.json
  userProfile=$($wkdir/node_modules/.bin/json2yaml "$DESCR_PATH"/userProfile.json)
  userProfile=${userProfile:4}
  $wkdir/node_modules/.bin/json2yaml $members_dir/$key.json > $members_dir/$now-$key.markdown
  sed -i 's/categories/tags/g' $members_dir/$now-$key.markdown
  cat << EOF >> $members_dir/$now-$key.markdown
$userProfile
  layout: profile
  title:  "$cn"
  date:   Date.parse('$now')
  categories: members
  permalink: /:categories/$uid/
---
EOF

  echo Generated $members_dir/$now-$key.markdown ...
done

if [[ ! -d "_posts/members" ]]; then
  mkdir "$wkdir/_posts/members"
fi

rm $wkdir/_posts/members/*

mv $members_dir/*.markdown $wkdir/_posts/members



for descriptor in `find $projects_dir -type f -regex '.*\.json'`; do
  filename=$(basename $descriptor)
  key=${filename%.json}

  project_name=$(node -pe 'JSON.parse(process.argv[1]).name' "$(cat $projects_dir/$key.json)")
  url=$(node -pe 'JSON.parse(process.argv[1]).website.website' "$(cat $projects_dir/$key.json)")
  parent=$(node -pe 'JSON.parse(process.argv[1]).parent' "$(cat $projects_dir/$key.json)")
  lastUpdates=$(curl -u dashbot:ghkf346LU538QZRD -X GET 'https://confluence.subutai.io/rest/api/content/search?cql=lastModified%3E=now(%22-5d%22)%20and%20space='$key'' -A 'ssf')
  lastUpdates=$(node -pe '
            var lastUpdates=[];
            var lastUpdate = {};
            if ('"$lastUpdates"'.results){
                for (var j=0; j<'"$lastUpdates"'.results.length; j++){
                var lUpd={};
                lUpd.id='"$lastUpdates"'.results[j].id;
                lUpd.type='"$lastUpdates"'.results[j].type;
                lUpd.title='"$lastUpdates"'.results[j].title;
                lUpd.url="https://confluence.subutai.io"+'"$lastUpdates"'.results[j]._links.webui;
                lastUpdates.push(lUpd);
                }
                lastUpdate.lastUpdates=lastUpdates;
                JSON.stringify(lastUpdate);
            }
            else {
                lastUpdate.lastUpdates=[];
                JSON.stringify(lastUpdate);
            }
           ')
  echo $lastUpdates > $DESCR_PATH/lastUpdates.json
  lastUpdates=$($wkdir/node_modules/.bin/json2yaml "$DESCR_PATH"/lastUpdates.json)
  lastUpdates=${lastUpdates:4}


  commits=$(curl -u dashbot:ghkf346LU538QZRD -X GET 'https://stash.subutai.io/rest/api/1.0/projects/'$key'/repos/main/commits/?until=master' -A 'ssf')
  commits=$(node -pe '
            var commits=[];
            var commit = {};
            if ('"$commits"'.values){
                for (var j=0; j<'"$commits"'.values.length; j++){
                var cmt={};
                cmt.id='"$commits"'.values[j].id;
                cmt.message='"$commits"'.values[j].message;
                cmt.author='"$commits"'.values[j].author.name;
                cmt.displayId='"$commits"'.values[j].displayId;
                cmt.url="https://stash.subutai.io/projects/'$key'/repos/main/commits/"+cmt.id;
                commits.push(cmt);
                }
                commit.commits=commits;
                JSON.stringify(commit);
            }
            else {
                commit.commits=[];
                JSON.stringify(commit);
            }
           ')
  echo $commits > $DESCR_PATH/commits.json
  commits=$($wkdir/node_modules/.bin/json2yaml "$DESCR_PATH"/commits.json)
  commits=${commits:4}

  blog=$(curl -u dashbot:ghkf346LU538QZRD -X GET 'https://confluence.subutai.io/rest/api/content?type=blogpost&spaceKey='$key'' -A 'ssf')
  blogs=$(node -pe '
                var blogs=[];
                var blog2 = {};
                if ('"$blog"'.results){
                    for (var i=0; i<'"$blog"'.results.length; i++){
                    var blog={};
                    blog.title = '"$blog"'.results[i].title;
                    blog.url = "https://confluence.subutai.io" + '"$blog"'.results[i]._links.webui;
                    blogs.push(blog);
                    }
                    blog2.blogs = blogs;
                    JSON.stringify(blog2);
                }
                else {
                    blog2.blogs = [];
                    JSON.stringify(blog2);
                }
                ')
  echo $blogs > $DESCR_PATH/blogs.json
  blogs=$($wkdir/node_modules/.bin/json2yaml "$DESCR_PATH"/blogs.json)
  blogs=${blogs:4}

  if [ -n '$parent' ] && [ "$parent" != "undefined" ]; then
    pkey=${parent%.json}
    parent=$(node -pe 'JSON.parse(process.argv[1]).website.website' "$(cat $projects_dir/$pkey.json)")
  else
    parent=''
  fi

  $wkdir/node_modules/.bin/json2yaml $projects_dir/$key.json > $projects_dir/$now-$key.markdown
  sed -i 's/categories/tags/g' $projects_dir/$now-$key.markdown
  cat << EOF >> $projects_dir/$now-$key.markdown

$lastUpdates
$commits
$blogs
  parenturl: $parent
  layout: post
  title:  "$project_name"
  date:   Date.parse('$now')
  categories: projects
  permalink: /:categories/$url/
---
EOF

  echo Generated $projects_dir/$now-$key.markdown ...
done

if [[ ! -d "_posts/projects" ]]; then
  mkdir "$wkdir/_posts/projects"
fi

rm $wkdir/_posts/projects/*

mv $projects_dir/*.markdown $wkdir/_posts/projects
