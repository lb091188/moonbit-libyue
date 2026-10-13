import { defineConfig } from 'vitepress'

const gh = 'https://github.com/lb091188/moonbit-native-gui'

// 落地页语言自动选择:首次访问根路径时,浏览器语言为中文则跳转 /zh/,
// 其余语言留在默认英文;用户手动切换过语言(localStorage 有记录)后不再跳转。
const langDetect = `(function () {
  try {
    if (localStorage.getItem('docs-lang')) return
    if (location.pathname !== '/' && location.pathname !== '/index.html') return
    var langs = navigator.languages && navigator.languages.length
      ? navigator.languages
      : [navigator.language || '']
    for (var i = 0; i < langs.length; i++) {
      if (String(langs[i]).toLowerCase().indexOf('zh') === 0) {
        localStorage.setItem('docs-lang', 'zh')
        location.replace('zh/')
        return
      }
    }
  } catch (e) {}
})()`

// Minimal TextMate grammar so ```moonbit blocks get keyword/string/number
// highlighting instead of falling back to plain text.
const moonbitGrammar = {
  name: 'moonbit',
  scopeName: 'source.moonbit',
  patterns: [{ include: '#expression' }],
  repository: {
    expression: {
      patterns: [
        { include: '#comments' },
        { include: '#strings' },
        { include: '#numbers' },
        { include: '#keywords' },
      ],
    },
    comments: {
      patterns: [
        { name: 'comment.line.double-slash.moonbit', match: '//.*$' },
      ],
    },
    strings: {
      patterns: [
        { name: 'string.quoted.double.moonbit', begin: '"', end: '"' },
      ],
    },
    numbers: {
      patterns: [
        { name: 'constant.numeric.moonbit', match: '\\b\\d[\\d_]*(?:\\.[\\d_]+)?\\b' },
      ],
    },
    keywords: {
      patterns: [
        {
          name: 'keyword.control.moonbit',
          match: '\\b(?:fn|let|mut|const|type|struct|enum|trait|impl|pub|priv|if|else|match|while|for|loop|return|break|continue|true|false|raise|try|catch|test|using|as|extern|derive|guard|Self)\\b',
        },
      ],
    },
  },
}

export default defineConfig({
  title: 'moonbit-libyue',
  description: 'MoonBit 原生跨平台桌面 GUI 库:自绘控件 + 自定义主题',
  cleanUrls: true,
  lastUpdated: true,
  head: [
    ['script', {}, langDetect],
  ],
  markdown: {
    languages: [moonbitGrammar],
  },
  themeConfig: {
    search: { provider: 'local' },
  },
  locales: {
    root: {
      label: 'English',
      lang: 'en',
      themeConfig: {
        nav: [
          { text: 'Docs', link: '/README' },
          { text: 'GitHub', link: gh },
        ],
        sidebar: [
          {
            text: 'Reference',
            items: [
              { text: 'Doc index', link: '/README' },
              { text: 'Platform adaptation', link: '/adaptation' },
              { text: 'Linux tray', link: '/tray' },
              { text: 'Autostart', link: '/autostart' },
            ],
          },
        ],
        docFooter: { prev: 'Previous', next: 'Next' },
        outline: { label: 'On this page' },
      },
    },
    zh: {
      label: '简体中文',
      lang: 'zh-CN',
      link: '/zh/',
      themeConfig: {
        nav: [
          { text: '文档', link: '/zh/README' },
          { text: 'GitHub', link: gh },
        ],
        sidebar: [
          {
            text: '指南',
            items: [
              { text: '系统能力总览', link: '/zh/system-capabilities' },
              { text: '开机自启动', link: '/zh/autostart' },
              { text: 'Linux 托盘', link: '/zh/tray' },
            ],
          },
          {
            text: '工程参考',
            items: [
              { text: '文档索引', link: '/zh/README' },
              { text: '前端化设计', link: '/zh/design' },
              { text: '平台适配经验', link: '/zh/adaptation' },
            ],
          },
        ],
        docFooter: { prev: '上一页', next: '下一页' },
        outline: { label: '页面目录' },
      },
    },
  },
})
