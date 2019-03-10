#!/bin/bash

cd public_gitee
git config user.name "Jeremy Xu"
git config user.email "jeremyxu2010@gmail.com"
git init
git add .
msg="rebuilding site `date`"
git commit -m "$msg"
git remote add origin git@gitee.com:jeremy-xu/jeremy-xu.git
git push -u --force origin master:master
cd ..