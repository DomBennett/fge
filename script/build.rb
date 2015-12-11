# Build docs for the FGE website from the /BES-QSIG/docs repository.
# Usage:
#  ruby build.rb
#  jekyll build
# Then, upload _site/ to gh-pages branch.

def mkfm(fm)
  # return doc front matter
  res = "---
layout: doc
authors: #{fm["authors"]}
lastchange: #{fm["lastchange"]}
title: #{fm["title"]}
status: #{fm["status"]}
permalink: #{fm["permalink"]}
source: #{fm["source"]}
source_author: #{fm["source_author"]}
---"
  return res
end

def mkgithubyml(gh)
  # return github user yaml info
  yml = "- name: #{gh["name"]}
  email: #{gh["email"]}
  affiliation: #{gh["affiliation"]}
  image: #{gh["image"]}
  github_username: #{gh["github_username"]}
  "
  return yml
end

def get_contributions(doc, path)
  #Return string of top three authors and their percentage contributions
  cmd = "cd #{path}/ && git log --stat #{doc}"
  log = `#{cmd}`
  commits = log.split(/commit\s[a-zA-Z0-9]+\n/)
  editors = {}
  for commit in commits[1..-1]
    lines = commit.strip().split(/\n/)
    name = lines[0].sub(/^Author:\s/, '')
    name = name.sub(/\s<.*/, '')
    changes = lines[-2].sub(/.*\s\|/, '')
    changes = changes.sub(/\+/, '')
    changes = changes.to_f()
    if !editors.has_key?(name)
      editors[name] = changes
    else
      editors[name] += changes
    end
  end
  total_changes = editors.values.inject(:+)
  for name in editors.keys
    percentage = editors[name]*100/total_changes
    editors[name] = percentage.round(2)
  end
  sorted = editors.sort_by { |k, v| v }
  author_string = ''
  for editor, changes in sorted.reverse
    author_string += "#{editor} (#{changes}%), "
  end
  return author_string.sub(/,\s$/, "")
end


def read_doc(infile)
  # Return strings of front matter and doc text
  text = File.read(infile)
  positions = text.enum_for(:scan, /\-\-\-/).map { Regexp.last_match.begin(0) }
  text_fm = text[positions[0]..positions[1]]
  fm = {}
  for e in text_fm.split(/\n/)
    if /: /.match(e)
      key, value = e.split(': ')
      fm[key] = value
    end
  end
  return fm, text[positions[3]..-1]
end

def run(input_dir, output_dir)
  # Make docs in _docs_repo/ FGE friendly"
  # get docs
  docs = Dir.glob(File.join(input_dir, "[^README]*.md"))
  for doc in docs
    puts doc
  end
  fm, doc = read_doc(doc)
  puts fm
  puts output_dir
end

#input_dir = '_docs_repo'
#output_dir = '_docs'
#run(input_dir, output_dir)
puts get_contributions("unix_ssh_introduction.md", "_docs_repo")
