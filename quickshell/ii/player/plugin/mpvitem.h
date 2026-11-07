#pragma once

#include <memory>

#include <QQuickFramebufferObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

struct mpv_handle;
struct mpv_render_context;

// The mpv core, kept alive by the item and by its renderer: the renderer is
// destroyed later and on another thread, and has to free its context first.
struct MpvCore {
    mpv_handle *handle = nullptr;
    ~MpvCore();
};

// Draws libmpv inside a Qt Quick scene through its render API, so the video is
// a normal item that QML can put its own controls over. On Wayland one window
// cannot be embedded in another, which rules out mpv's own window.
class MpvItem : public QQuickFramebufferObject {
    Q_OBJECT
    QML_ELEMENT
    // mpv cannot open a video until the renderer exists, which is only once the
    // window is on screen. Nothing should be loaded before this is true.
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit MpvItem(QQuickItem *parent = nullptr);
    ~MpvItem() override;

    Renderer *createRenderer() const override;

    bool ready() const { return m_ready; }
    void setReady();

    Q_INVOKABLE void command(const QVariantList &args);
    // Waits for mpv to finish, for what has to be done before the app exits.
    Q_INVOKABLE void commandSync(const QVariantList &args);
    Q_INVOKABLE void setProperty(const QString &name, const QVariant &value);
    Q_INVOKABLE QVariant getProperty(const QString &name) const;
    Q_INVOKABLE void observeProperty(const QString &name);

signals:
    void readyChanged();
    void propertyChanged(const QString &name, const QVariant &value);
    void fileLoaded();
    void endFile(const QString &reason, const QString &error);
    void logMessage(const QString &level, const QString &text);

private:
    void drainEvents();

    std::shared_ptr<MpvCore> m_core;
    quint64 m_observers = 0;
    bool m_ready = false;
};
