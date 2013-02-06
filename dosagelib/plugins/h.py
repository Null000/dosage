# Copyright (C) 2012-2013 Bastian Kleineidam

from re import compile
from ..scraper import _BasicScraper
from ..util import tagre


class HijinksEnsue(_BasicScraper):
    url = 'http://hijinksensue.com/'
    stripUrl = url + '%s/'
    imageSearch = compile(tagre("img", "src", r'(http://hijinksensue\.com/comics/\d+-\d+-\d+[^"]+)'))
    prevSearch = compile(tagre("a", "href", r'(http://hijinksensue\.com/\d+/\d+/\d+/[^"]+)', after="navi-prev"))
    help = 'Index format: yyyy/mm/dd/name'


class HorribleVille(_BasicScraper):
    url = 'http://horribleville.com/'
    stripUrl = url + 'd/%s.html'
    imageSearch = compile(tagre("img", "src", r'(/comics/[^"]+)'))
    prevSearch = compile(tagre("a", "href", r'(/d/[^"]+)') + tagre("img", "src", r'/images/previous\.png'))
    help = 'Index format: yyyymmdd'