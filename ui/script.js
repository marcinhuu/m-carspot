let Locales = {};

function _T(key, ...args) {
    if (!Locales || Object.keys(Locales).length === 0) return key;
    let str = Locales[key] || key;
    if (args.length) {
        let i = 0;
        str = str.replace(/%[sd]/g, () => {
            const val = args[i++];
            return val !== undefined && val !== null ? String(val) : '';
        });
    }
    return str;
}

function updateUIText(root) {
    const scope = root || document;
    scope.querySelectorAll('[data-locale]').forEach(el => {
        const key = el.getAttribute('data-locale');
        if (key) el.textContent = _T(key);
    });
    scope.querySelectorAll('[data-locale-placeholder]').forEach(el => {
        const key = el.getAttribute('data-locale-placeholder');
        if (key) el.placeholder = _T(key);
    });
    scope.querySelectorAll('[data-locale-title]').forEach(el => {
        const key = el.getAttribute('data-locale-title');
        if (key) el.title = _T(key);
    });
}

async function loadLocales() {
    try {
        const result = await fetchNui('carspot:getLocales');
        if (result && result.locales) {
            Locales = result.locales;
            updateUIText();
        }
    } catch (e) {}
}

function photoPickerHtml(textKey) {
    return `<svg viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg><span>${_T(textKey)}</span>`;
}

const State = {
    currentView: 'feed',
    previousView: 'feed',
    feedOffset: 0,
    feedLoading: false,
    feedDone: false,
    myProfile: null,
    viewingProfile: null,
    isOwnProfile: false,
    garageOwnerCid: null,
    garageIsOwn: false,
    editAvatarData: null,
    editBannerData: null,
    cpPhotoData: null,
    cePhotoData: null,
    agPhotoData: null,
    currentPostId: null,
};

function $(id) { return document.getElementById(id); }
function fa(name) { return `<i class="fas fa-${name}"></i>`; }

const MAIN_VIEWS = new Set(['feed', 'events', 'ranking', 'profile', 'create-post']);
function timeAgo(dateStr) {
    const now = Date.now();
    const then = new Date(dateStr).getTime();
    const diff = Math.floor((now - then) / 1000);
    if (diff < 60) return _T('time_just_now');
    if (diff < 3600) return _T('time_minutes_ago', Math.floor(diff / 60));
    if (diff < 86400) return _T('time_hours_ago', Math.floor(diff / 3600));
    return _T('time_days_ago', Math.floor(diff / 86400));
}
function formatDate(str) {
    if (!str) return '';
    return new Date(str).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
}
function avatarInitial(name) {
    return (name || '?')[0].toUpperCase();
}
function renderAvatar(avatar, name, cls = 'avatar') {
    if (avatar && avatar.length > 10) {
        return `<div class="${cls}"><img src="${avatar}" onerror="this.parentElement.textContent='${avatarInitial(name)}'" /></div>`;
    }
    return `<div class="${cls}">${avatarInitial(name)}</div>`;
}
function showToast(msg, type = '') {
    const t = $('toast');
    t.textContent = msg;
    t.className = 'toast ' + type + ' show';
    clearTimeout(t._to);
    t._to = setTimeout(() => { t.className = 'toast'; }, 2800);
}
function eventTypeLabel(type) {
    const map = {
        car_meet: { icon: 'car', label: _T('event_type_car_meet') },
        drag_race: { icon: 'flag-checkered', label: _T('event_type_drag_race') },
        drift_night: { icon: 'wind', label: _T('event_type_drift_night') },
        offroad: { icon: 'mountain', label: _T('event_type_offroad') },
        other: { icon: 'map-pin', label: _T('event_type_other') }
    };
    const item = map[type] || { icon: 'map-pin', label: type };
    return `${fa(item.icon)} ${item.label}`;
}
function vehicleClassLabel(c) {
    if (!c) return '';
    return `<span class="class-badge">${c}</span>`;
}

function showView(viewId, fromBack = false) {
    const prev = document.querySelector('.view.active');
    const next = $('view-' + viewId);
    if (!next) return;

    const instant = prev && MAIN_VIEWS.has(viewId) && MAIN_VIEWS.has(State.currentView);
    const useSlide = prev && !fromBack && !instant;

    if (prev) {
        if (useSlide) {
            prev.classList.add('slide-out');
            setTimeout(() => prev.classList.remove('slide-out', 'active'), 200);
        } else {
            prev.classList.remove('active', 'slide-out', 'instant');
        }
    }

    if (instant) next.classList.add('instant');
    next.classList.add('active');
    if (instant) {
        requestAnimationFrame(() => next.classList.remove('instant'));
    }

    State.previousView = State.currentView;
    State.currentView = viewId;

    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    const navMatch = document.querySelector(`.nav-btn[data-view="${viewId}"]`);
    if (navMatch) navMatch.classList.add('active');

    if (viewId !== 'post-detail') {
        $('post-comment-form').style.display = 'none';
    }
}

document.querySelectorAll('.back-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const target = btn.dataset.back || 'feed';
        showView(target, true);
    });
});

document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const view = btn.dataset.view;
        if (!view) return;
        if (State.currentView === view && view !== 'create-post') return;
        if (view === 'feed') loadFeed(true);
        if (view === 'events') loadEvents();
        if (view === 'ranking') loadRanking();
        if (view === 'profile') loadMyProfile();
        if (view === 'create-post') openCreatePost();
        showView(view);
    });
});

async function loadFeed(reset = false) {
    if (reset) {
        State.feedOffset = 0;
        State.feedDone = false;
        $('feed-list').innerHTML = `<div class="loading-spinner" id="feed-loading"><div class="spinner"></div></div>`;
        $('feed-end-msg').style.display = 'none';
    }
    if (State.feedLoading || State.feedDone) return;
    State.feedLoading = true;

    const posts = await fetchNui('carspot:getFeed', { offset: State.feedOffset });
    State.feedLoading = false;

    const loading = $('feed-loading');
    if (loading) loading.remove();

    if (!posts || posts.length === 0) {
        if (State.feedOffset === 0) {
            $('feed-list').innerHTML = `
                <div class="empty-state">
                    <svg viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>
                    <p>${_T('feed_empty')}</p>
                </div>`;
        } else {
            State.feedDone = true;
            $('feed-end-msg').style.display = 'block';
        }
        return;
    }

    posts.forEach(p => {
        const el = buildFeedCard(p);
        $('feed-list').appendChild(el);
    });
    State.feedOffset += posts.length;
    if (posts.length < 10) {
        State.feedDone = true;
        $('feed-end-msg').style.display = 'block';
    }
}

function buildFeedCard(p) {
    const div = document.createElement('div');
    div.className = 'feed-card';
    div.dataset.id = p.id;
    const liked = parseInt(p.liked_by_me) > 0;
    const saved = parseInt(p.saved_by_me) > 0;

    div.innerHTML = `
        <div class="card-header">
            <div class="avatar" data-cid="${p.citizenid}">${p.author_avatar && p.author_avatar.length > 10
                ? `<img src="${p.author_avatar}" onerror="this.parentElement.textContent='${avatarInitial(p.username)}'" />`
                : avatarInitial(p.username)}</div>
            <div class="card-author-info">
                <div class="card-username" data-cid="${p.citizenid}">${p.username || _T('unknown')}</div>
                <div class="card-meta">${timeAgo(p.created_at)}${p.location ? ' · ' + fa('location-dot') + ' ' + p.location : ''}</div>
            </div>
            <button class="card-more-btn" data-id="${p.id}" data-own="${p.citizenid === State.myProfile?.citizenid ? '1' : '0'}">···</button>
        </div>
        <div class="card-image" data-id="${p.id}">
            ${p.image && p.image.length > 10
                ? `<img src="${p.image}" loading="lazy" />`
                : `<div class="card-image-placeholder">${fa('car')}</div>`}
        </div>
        <div class="card-actions">
            <button class="action-btn like-btn ${liked ? 'liked' : ''}" data-id="${p.id}">
                <svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/></svg>
                <span>${p.likes_count || 0}</span>
            </button>
            <button class="action-btn comment-btn" data-id="${p.id}">
                <svg viewBox="0 0 24 24"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>
                <span>${p.comments_count || 0}</span>
            </button>
            <div class="action-spacer"></div>
            <button class="action-btn save-btn ${saved ? 'saved' : ''}" data-id="${p.id}">
                <svg viewBox="0 0 24 24"><path d="M19 21l-7-5-7 5V5a2 2 0 012-2h10a2 2 0 012 2z"/></svg>
            </button>
        </div>
        <div class="card-body">
            <div class="card-title" data-id="${p.id}">${p.title}</div>
            ${p.description ? `<div class="card-desc">${p.description}</div>` : ''}
            ${p.vehicle_model ? `
                <div class="vehicle-badge" data-id="${p.id}">
                    <svg viewBox="0 0 24 24"><path d="M5 17H3a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v9"/><rect x="11" y="17" width="9" height="4" rx="1"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>
                    ${p.vehicle_brand ? p.vehicle_brand + ' ' : ''}${p.vehicle_model}
                    ${p.vehicle_plate ? '· ' + p.vehicle_plate : ''}
                    ${vehicleClassLabel(p.vehicle_class)}
                </div>` : ''}
        </div>
    `;

    div.querySelectorAll('[data-cid]').forEach(el => {
        el.addEventListener('click', () => openProfile(el.dataset.cid));
    });
    div.querySelectorAll('.card-image, .card-title').forEach(el => {
        el.addEventListener('click', () => openPost(p.id));
    });
    div.querySelector('.vehicle-badge')?.addEventListener('click', () => openPost(p.id));
    div.querySelector('.like-btn').addEventListener('click', async (e) => {
        e.stopPropagation();
        const btn = div.querySelector('.like-btn');
        const res = await fetchNui('carspot:likePost', { id: p.id });
        btn.classList.toggle('liked', res.liked);
        const liked = res.liked;
        const newCount = parseInt(btn.querySelector('span').textContent) + (liked ? 1 : -1);
        btn.querySelector('span').textContent = Math.max(0, newCount);
        p.liked_by_me = liked ? 1 : 0;
    });
    div.querySelector('.comment-btn').addEventListener('click', () => openPost(p.id));
    div.querySelector('.save-btn').addEventListener('click', async (e) => {
        e.stopPropagation();
        const btn = div.querySelector('.save-btn');
        const res = await fetchNui('carspot:savePost', { id: p.id });
        btn.classList.toggle('saved', res.saved);
        showToast(res.message, res.saved ? 'success' : '');
    });
    div.querySelector('.card-more-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        const isOwn = div.querySelector('.card-more-btn').dataset.own === '1';
        const buttons = isOwn
            ? [{ title: _T('post_delete'), color: 'red', cb: async () => {
                    const r = await fetchNui('carspot:deletePost', { id: p.id });
                    if (r.success) { div.remove(); showToast(r.message, 'success'); }
                    else showToast(r.message, 'error');
                }}]
            : [{ title: _T('post_save'), color: 'blue', cb: async () => {
                    const r = await fetchNui('carspot:savePost', { id: p.id });
                    showToast(r.message, r.saved ? 'success' : '');
                }}];
        setContextMenu({ title: _T('post_options'), buttons });
    });
    return div;
}

$('feed-list').addEventListener('scroll', () => {
    const el = $('feed-list');
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
        loadFeed(false);
    }
});

$('btn-saved').addEventListener('click', async () => {
    showView('saved');
    $('saved-list').innerHTML = `<div class="loading-spinner"><div class="spinner"></div></div>`;
    const posts = await fetchNui('carspot:getSavedPosts', {});
    $('saved-list').innerHTML = '';
    if (!posts || posts.length === 0) {
        $('saved-list').innerHTML = `<div class="empty-state">
            <svg viewBox="0 0 24 24"><path d="M19 21l-7-5-7 5V5a2 2 0 012-2h10a2 2 0 012 2z"/></svg>
            <p>${_T('saved_empty')}</p></div>`;
        return;
    }
    posts.forEach(p => $('saved-list').appendChild(buildFeedCard(p)));
});

async function openPost(id) {
    showView('post-detail');
    $('post-detail-content').innerHTML = `<div class="loading-spinner"><div class="spinner"></div></div>`;
    $('post-comment-form').style.display = 'none';
    const post = await fetchNui('carspot:getPost', { id });
    if (!post) {
        $('post-detail-content').innerHTML = `<div class="empty-state"><p>${_T('post_not_found')}</p></div>`;
        return;
    }
    const liked = parseInt(post.liked_by_me) > 0;
    const saved = parseInt(post.saved_by_me) > 0;

    $('post-detail-content').innerHTML = `
        <div class="detail-image">
            ${post.image && post.image.length > 10
                ? `<img src="${post.image}" />`
                : `<div class="card-image-placeholder">${fa('car')}</div>`}
        </div>
        <div class="detail-body">
            <div class="detail-author-row">
                ${renderAvatar(post.author_avatar, post.username)}
                <div style="flex:1">
                    <div class="detail-author-name" data-cid="${post.citizenid}">${post.username || _T('unknown')}</div>
                    <div class="detail-date">${formatDate(post.created_at)}${post.location ? ' · ' + fa('location-dot') + ' ' + post.location : ''}</div>
                </div>
            </div>
            <div class="detail-actions">
                <button class="action-btn like-btn ${liked ? 'liked' : ''}" id="detail-like-btn">
                    <svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/></svg>
                    <span id="detail-likes-count">${post.likes_count || 0}</span>
                </button>
                <div class="action-spacer"></div>
                <button class="action-btn save-btn ${saved ? 'saved' : ''}" id="detail-save-btn">
                    <svg viewBox="0 0 24 24"><path d="M19 21l-7-5-7 5V5a2 2 0 012-2h10a2 2 0 012 2z"/></svg>
                </button>
            </div>
            <div class="detail-title">${post.title}</div>
            ${post.description ? `<div class="detail-desc">${post.description}</div>` : ''}
            ${post.vehicle_model ? `
                <div class="vehicle-info-card">
                    <div class="vic-title">${_T('post_vehicle_info_title')}</div>
                    ${post.vehicle_brand ? `<div class="vic-row"><span class="vic-label">${_T('post_brand')}</span><span class="vic-value">${post.vehicle_brand}</span></div>` : ''}
                    <div class="vic-row"><span class="vic-label">${_T('post_model')}</span><span class="vic-value">${post.vehicle_model}${vehicleClassLabel(post.vehicle_class)}</span></div>
                    ${post.vehicle_plate ? `<div class="vic-row"><span class="vic-label">${_T('post_plate')}</span><span class="vic-value">${post.vehicle_plate}</span></div>` : ''}
                    ${post.vehicle_color ? `<div class="vic-row"><span class="vic-label">${_T('post_color')}</span><span class="vic-value">${post.vehicle_color}</span></div>` : ''}
                    ${post.vehicle_mods ? `<div class="vic-mods">${post.vehicle_mods}</div>` : ''}
                </div>` : ''}
            <div class="comments-section">
                <div class="comments-title">${_T('post_comments', (post.comments || []).length)}</div>
                <div id="comments-list">
                    ${(post.comments || []).map(c => renderComment(c)).join('')}
                </div>
            </div>
        </div>
    `;

    $('comment-input').value = '';
    $('post-comment-form').style.display = 'flex';
    State.currentPostId = post.id;

    document.querySelector('.detail-author-name[data-cid]')?.addEventListener('click', () => {
        openProfile(post.citizenid);
    });
    $('detail-like-btn').addEventListener('click', async () => {
        const res = await fetchNui('carspot:likePost', { id: post.id });
        $('detail-like-btn').classList.toggle('liked', res.liked);
        const cur = parseInt($('detail-likes-count').textContent);
        $('detail-likes-count').textContent = Math.max(0, cur + (res.liked ? 1 : -1));
    });
    $('detail-save-btn').addEventListener('click', async () => {
        const res = await fetchNui('carspot:savePost', { id: post.id });
        $('detail-save-btn').classList.toggle('saved', res.saved);
        showToast(res.message, res.saved ? 'success' : '');
    });
}

function renderComment(c) {
    return `<div class="comment-item">
        ${renderAvatar(c.avatar, c.username, 'avatar-sm')}
        <div class="comment-body">
            <span class="comment-username">${c.username || _T('unknown')}</span>
            <div class="comment-text">${c.content}</div>
            <div class="comment-time">${timeAgo(c.created_at)}</div>
        </div>
    </div>`;
}

function openCreatePost() {
    State.cpPhotoData = null;
    $('cp-title').value = '';
    $('cp-desc').value = '';
    $('cp-location').value = '';
    $('cp-brand').value = '';
    $('cp-model').value = '';
    $('cp-plate').value = '';
    $('cp-color').value = '';
    $('cp-class').value = '';
    $('cp-mods').value = '';
    $('cp-photo-preview').innerHTML = photoPickerHtml('post_tap_photo');
}

$('cp-photo-picker').addEventListener('click', () => {
    selectGallery({ includeImages: true, includeVideos: false, cb: (data) => {
        State.cpPhotoData = data ? data.src || data : null;
        $('cp-photo-preview').innerHTML = State.cpPhotoData
            ? `<img src="${State.cpPhotoData}" style="width:100%;height:100%;object-fit:cover" />`
            : photoPickerHtml('post_tap_photo');
    }});
});

$('btn-submit-post').addEventListener('click', async () => {
    const title = $('cp-title').value.trim();
    if (!title) { showToast(_T('post_title_required'), 'error'); return; }
    $('btn-submit-post').disabled = true;
    const res = await fetchNui('carspot:createPost', {
        title,
        description: $('cp-desc').value.trim(),
        image: State.cpPhotoData || '',
        location: $('cp-location').value.trim(),
        vehicle_brand: $('cp-brand').value.trim(),
        vehicle_model: $('cp-model').value.trim(),
        vehicle_plate: $('cp-plate').value.trim(),
        vehicle_color: $('cp-color').value.trim(),
        vehicle_class: $('cp-class').value,
        vehicle_mods: $('cp-mods').value.trim(),
    });
    $('btn-submit-post').disabled = false;
    if (res.success) {
        showToast(res.message, 'success');
        showView('feed', true);
        loadFeed(true);
    } else {
        showToast(res.message, 'error');
    }
});

async function loadMyProfile() {
    $('profile-back-btn').style.display = 'none';
    $('btn-edit-profile').style.display = 'flex';
    $('btn-follow-user').style.display = 'none';
    const profile = await fetchNui('carspot:getProfile', {});
    if (!profile) return;
    State.myProfile = profile;
    State.viewingProfile = profile.citizenid;
    State.isOwnProfile = true;
    $('profile-header-name').textContent = '@' + (profile.username || _T('header_profile'));
    renderProfile(profile, true);
}

async function openProfile(citizenid) {
    showView('profile');
    $('profile-content').innerHTML = `<div class="loading-spinner"><div class="spinner"></div></div>`;
    const profile = await fetchNui('carspot:getProfile', { citizenid });
    if (!profile) {
        $('profile-content').innerHTML = `<div class="empty-state"><p>${_T('profile_not_found')}</p></div>`;
        return;
    }
    const isOwn = !!profile.isOwn;
    State.viewingProfile = citizenid;
    State.isOwnProfile = isOwn;
    $('profile-header-name').textContent = '@' + (profile.username || _T('header_profile'));
    $('profile-back-btn').style.display = isOwn ? 'none' : 'flex';
    $('btn-edit-profile').style.display = isOwn ? 'flex' : 'none';

    const followBtn = $('btn-follow-user');
    if (!isOwn) {
        followBtn.style.display = 'flex';
        followBtn.textContent = profile.isFollowing ? _T('profile_following_btn') : _T('profile_follow');
        followBtn.className = 'btn-follow' + (profile.isFollowing ? ' following' : '');
        followBtn.onclick = async () => {
            const res = await fetchNui('carspot:followUser', { citizenid });
            followBtn.textContent = res.following ? _T('profile_following_btn') : _T('profile_follow');
            followBtn.className = 'btn-follow' + (res.following ? ' following' : '');
            showToast(res.message, res.following ? 'success' : '');
        };
    } else {
        followBtn.style.display = 'none';
    }

    renderProfile(profile, isOwn);
}

function renderProfile(profile, isOwn) {
    const bannerHtml = profile.banner && profile.banner.length > 10
        ? `<img src="${profile.banner}" alt="" />`
        : '';
    $('profile-content').innerHTML = `
        <div class="profile-banner">${bannerHtml}</div>
        <div style="position:relative">
            <div class="profile-avatar-wrap">
                <div class="profile-avatar">
                    ${profile.avatar && profile.avatar.length > 10
                        ? `<img src="${profile.avatar}" onerror="this.textContent='${avatarInitial(profile.username)}'" />`
                        : avatarInitial(profile.username)}
                </div>
            </div>
        </div>
        <div class="profile-info">
            <div class="profile-username">@${profile.username}</div>
            ${profile.bio ? `<div class="profile-bio">${profile.bio}</div>` : ''}
            <div class="profile-stats">
                <div class="stat-item">
                    <span class="stat-value">${profile.post_count || 0}</span>
                    <span class="stat-label">${_T('profile_posts')}</span>
                </div>
                <div class="stat-item">
                    <span class="stat-value">${profile.followers || 0}</span>
                    <span class="stat-label">${_T('profile_followers')}</span>
                </div>
                <div class="stat-item">
                    <span class="stat-value">${profile.following || 0}</span>
                    <span class="stat-label">${_T('profile_following')}</span>
                </div>
            </div>
        </div>
        <div class="profile-tabs">
            <button class="profile-tab active" id="tab-posts">
                <svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></svg>
                ${_T('profile_tab_posts')}
            </button>
            <button class="profile-tab" id="tab-garage">
                <svg viewBox="0 0 24 24"><path d="M5 17H3a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v9"/><rect x="11" y="17" width="9" height="4" rx="1"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>
                ${_T('profile_tab_garage')}
            </button>
        </div>
        <div id="profile-tab-content"></div>
    `;

    loadProfilePosts(profile.citizenid);

    $('tab-posts').addEventListener('click', () => {
        $('tab-posts').classList.add('active');
        $('tab-garage').classList.remove('active');
        loadProfilePosts(profile.citizenid);
    });
    $('tab-garage').addEventListener('click', () => {
        $('tab-garage').classList.add('active');
        $('tab-posts').classList.remove('active');
        loadGarageInline(profile.citizenid, isOwn);
    });
}

async function loadProfilePosts(citizenid) {
    $('profile-tab-content').innerHTML = `<div class="loading-spinner"><div class="spinner"></div></div>`;
    const posts = await fetchNui('carspot:getUserPosts', { citizenid });
    if (!posts || posts.length === 0) {
        $('profile-tab-content').innerHTML = `<div class="empty-state">
            <svg viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>
            <p>${_T('profile_no_posts')}</p></div>`;
        return;
    }
    $('profile-tab-content').innerHTML = '<div class="profile-grid" id="profile-grid"></div>';
    posts.forEach(p => {
        const item = document.createElement('div');
        item.className = 'profile-grid-item';
        item.innerHTML = `
            ${p.image && p.image.length > 10
                ? `<img src="${p.image}" loading="lazy" />`
                : `<div class="grid-placeholder">${fa('car')}</div>`}
            <div class="grid-overlay">
                <svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/></svg>
            </div>
        `;
        item.addEventListener('click', () => openPost(p.id));
        $('profile-grid').appendChild(item);
    });
}

function renderCoverPreview(url) {
    const el = $('edit-cover-preview');
    el.innerHTML = url && url.length > 10
        ? `<img src="${url}" alt="" />`
        : `<span class="edit-cover-placeholder">${fa('image')}</span>`;
}

$('btn-edit-profile').addEventListener('click', () => {
    showView('edit-profile');
    if (State.myProfile) {
        $('ep-username').value = State.myProfile.username || '';
        $('ep-bio').value = State.myProfile.bio || '';
        State.editAvatarData = State.myProfile.avatar || null;
        State.editBannerData = State.myProfile.banner || null;
        const av = $('edit-avatar-preview');
        av.innerHTML = State.editAvatarData && State.editAvatarData.length > 10
            ? `<img src="${State.editAvatarData}" />`
            : avatarInitial(State.myProfile.username);
        renderCoverPreview(State.editBannerData);
    }
});

$('btn-change-cover').addEventListener('click', () => {
    selectGallery({ includeImages: true, includeVideos: false, cb: (data) => {
        State.editBannerData = data ? data.src || data : null;
        renderCoverPreview(State.editBannerData);
    }});
});

$('btn-change-avatar').addEventListener('click', () => {
    selectGallery({ includeImages: true, includeVideos: false, cb: (data) => {
        State.editAvatarData = data ? data.src || data : null;
        const av = $('edit-avatar-preview');
        av.innerHTML = State.editAvatarData
            ? `<img src="${State.editAvatarData}" style="width:100%;height:100%;object-fit:cover;border-radius:50%" />`
            : avatarInitial($('ep-username').value || '?');
    }});
});

$('btn-save-profile').addEventListener('click', async () => {
    const username = $('ep-username').value.trim();
    const bio = $('ep-bio').value.trim();
    if (!username) { showToast(_T('profile_username_required'), 'error'); return; }
    $('btn-save-profile').disabled = true;
    const res = await fetchNui('carspot:updateProfile', {
        username,
        bio,
        avatar: State.editAvatarData || '',
        banner: State.editBannerData || ''
    });
    $('btn-save-profile').disabled = false;
    if (res.success) {
        showToast(res.message, 'success');
        showView('profile', true);
        loadMyProfile();
    } else {
        showToast(res.message, 'error');
    }
});

async function loadGarageInline(citizenid, isOwn) {
    const tc = $('profile-tab-content');
    tc.innerHTML = `<div class="loading-spinner"><div class="spinner"></div></div>`;
    const vehicles = await fetchNui('carspot:getGarage', { citizenid });
    tc.innerHTML = '';

    const header = document.createElement('div');
    header.className = 'inline-garage-header';
    header.innerHTML = `<span>${_T('profile_my_garage')}</span>`;
    if (isOwn) {
        const addBtn = document.createElement('button');
        addBtn.className = 'btn-add-inline';
        addBtn.title = _T('garage_add_vehicle');
        addBtn.innerHTML = fa('plus');
        addBtn.addEventListener('click', openVehiclePicker);
        header.appendChild(addBtn);
    }
    tc.appendChild(header);

    if (!vehicles || vehicles.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.innerHTML = `<svg viewBox="0 0 24 24"><path d="M5 17H3a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v9"/><rect x="11" y="17" width="9" height="4" rx="1"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg><p>${_T('garage_no_vehicles')}</p>`;
        tc.appendChild(empty);
        return;
    }
    vehicles.forEach(v => tc.appendChild(buildGarageCard(v, isOwn)));
}

async function openVehiclePicker() {
    const overlay = $('vehicle-picker-overlay');
    const list = $('vehicle-picker-list');
    list.innerHTML = `<div class="loading-spinner"><div class="spinner"></div></div>`;
    overlay.classList.add('open');

    const vehicles = await fetchNui('carspot:getOwnedVehicles', {});
    list.innerHTML = '';

    if (!vehicles || vehicles.length === 0) {
        list.innerHTML = `<div class="empty-state" style="padding:30px"><p>${_T('garage_picker_empty')}</p></div>`;
        return;
    }

    vehicles.forEach(v => {
        const item = document.createElement('div');
        item.className = 'vehicle-picker-item';
        const model = v.vehicle || v.model || _T('unknown');
        const plate = v.plate || '';
        item.innerHTML = `
            <div class="vehicle-picker-icon">${fa('car')}</div>
            <div class="vehicle-picker-info">
                <div class="vehicle-picker-model">${model.toUpperCase()}</div>
                ${plate ? `<div class="vehicle-picker-plate">${plate}</div>` : ''}
            </div>
        `;
        item.addEventListener('click', () => {
            overlay.classList.remove('open');
            State.agPhotoData = null;
            $('ag-model').value = model;
            $('ag-plate').value = plate;
            $('ag-brand').value = '';
            $('ag-color').value = '';
            $('ag-mods').value = '';
            $('ag-class').value = '';
            $('ag-photo-preview').innerHTML = photoPickerHtml('garage_tap_photo');
            showView('add-garage');
        });
        list.appendChild(item);
    });
}

async function openGarage(citizenid, isOwn) {
    State.garageOwnerCid = citizenid;
    State.garageIsOwn = isOwn;
    showView('garage');
    $('btn-add-garage-vehicle').style.display = isOwn ? 'flex' : 'none';
    $('garage-list').innerHTML = `<div class="loading-spinner"><div class="spinner"></div></div>`;
    const vehicles = await fetchNui('carspot:getGarage', { citizenid });
    $('garage-list').innerHTML = '';
    if (!vehicles || vehicles.length === 0) {
        $('garage-list').innerHTML = `<div class="empty-state">
            <svg viewBox="0 0 24 24"><path d="M5 17H3a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v9"/><rect x="11" y="17" width="9" height="4" rx="1"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>
            <p>${_T('garage_empty')}</p></div>`;
        return;
    }
    vehicles.forEach(v => $('garage-list').appendChild(buildGarageCard(v, isOwn)));
}

function buildGarageCard(v, isOwn) {
    const div = document.createElement('div');
    div.className = 'garage-card';
    div.innerHTML = `
        <div class="garage-img">
            ${v.image && v.image.length > 10
                ? `<img src="${v.image}" loading="lazy" />`
                : `<div class="garage-img-placeholder">${fa('car')}</div>`}
        </div>
        <div class="garage-body">
            <div class="garage-car-name">
                ${v.vehicle_brand ? v.vehicle_brand + ' ' : ''}${v.vehicle_model}
                ${vehicleClassLabel(v.vehicle_class)}
            </div>
            <div class="garage-meta-row">
                ${v.vehicle_plate ? `<span class="garage-chip">${fa('id-card')} ${v.vehicle_plate}</span>` : ''}
                ${v.vehicle_color ? `<span class="garage-chip">${fa('palette')} ${v.vehicle_color}</span>` : ''}
            </div>
            ${v.vehicle_mods ? `<div class="garage-mods">${v.vehicle_mods}</div>` : ''}
            <div class="garage-footer">
                <div class="garage-likes">
                    <svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/></svg>
                    ${v.likes_count || 0} likes
                </div>
                ${isOwn ? `<button class="btn-danger" data-id="${v.id}">${_T('remove')}</button>` : ''}
            </div>
        </div>
    `;
    if (isOwn) {
        div.querySelector('.btn-danger').addEventListener('click', async () => {
            const res = await fetchNui('carspot:removeGarageVehicle', { id: v.id });
            if (res.success) { div.remove(); showToast(res.message, 'success'); }
            else showToast(res.message, 'error');
        });
    }
    return div;
}

$('btn-add-garage-vehicle').addEventListener('click', () => openVehiclePicker());

$('vehicle-picker-overlay').addEventListener('click', e => {
    if (e.target === $('vehicle-picker-overlay')) {
        $('vehicle-picker-overlay').classList.remove('open');
    }
});

$('ag-photo-picker').addEventListener('click', () => {
    selectGallery({ includeImages: true, includeVideos: false, cb: (data) => {
        State.agPhotoData = data ? data.src || data : null;
        $('ag-photo-preview').innerHTML = State.agPhotoData
            ? `<img src="${State.agPhotoData}" style="width:100%;height:100%;object-fit:cover" />`
            : photoPickerHtml('post_tap_photo');
    }});
});

$('btn-submit-garage').addEventListener('click', async () => {
    const brand = $('ag-brand').value.trim();
    const model = $('ag-model').value.trim();
    if (!model) { showToast(_T('garage_model_required'), 'error'); return; }
    $('btn-submit-garage').disabled = true;
    const res = await fetchNui('carspot:addGarageVehicle', {
        vehicle_brand: brand,
        vehicle_model: model,
        vehicle_plate: $('ag-plate').value.trim(),
        vehicle_color: $('ag-color').value.trim(),
        vehicle_class: $('ag-class').value,
        vehicle_mods: $('ag-mods').value.trim(),
        image: State.agPhotoData || ''
    });
    $('btn-submit-garage').disabled = false;
    if (res.success) {
        showToast(res.message, 'success');
        showView('garage', true);
        openGarage(State.garageOwnerCid, true);
    } else {
        showToast(res.message, 'error');
    }
});

async function loadEvents() {
    $('events-list').innerHTML = `<div class="loading-spinner" id="events-loading"><div class="spinner"></div></div>`;
    const events = await fetchNui('carspot:getEvents', {});
    $('events-list').innerHTML = '';
    if (!events || events.length === 0) {
        $('events-list').innerHTML = `<div class="empty-state">
            <svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
            <p>${_T('event_empty')}</p></div>`;
        return;
    }
    events.forEach(ev => $('events-list').appendChild(buildEventCard(ev)));
}

function updateEventAttendUI(div, ev, btn, res) {
    btn.classList.toggle('attending', res.attending);
    btn.innerHTML = res.attending ? `${fa('check')} ${_T('event_attending_btn')}` : _T('event_attend');
    showToast(res.message, res.attending ? 'success' : '');
    const countEl = div.querySelector('.event-meta-item:last-child');
    ev.attendee_count = Math.max(0, ev.attendee_count + (res.attending ? 1 : -1));
    countEl.innerHTML = `<svg viewBox="0 0 24 24"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>${ev.attendee_count} / ${ev.max_participants}`;
}

async function confirmAttendEvent(ev, div, btn, notify) {
    const res = await fetchNui('carspot:attendEvent', { id: ev.id, notify });
    updateEventAttendUI(div, ev, btn, res);
}

function buildEventCard(ev) {
    const div = document.createElement('div');
    div.className = 'event-card';
    const attending = parseInt(ev.attending) > 0;
    const fill = ev.max_participants > 0 ? Math.min(100, Math.round((ev.attendee_count / ev.max_participants) * 100)) : 0;

    div.innerHTML = `
        <div class="event-banner">
            ${ev.image && ev.image.length > 10 ? `<img src="${ev.image}" />` : ''}
            <div class="event-type-badge">${eventTypeLabel(ev.type)}</div>
        </div>
        <div class="event-body">
            <div class="event-name">${ev.name}</div>
            ${ev.description ? `<div class="event-desc">${ev.description}</div>` : ''}
            <div class="event-meta-row">
                <div class="event-meta-item">
                    <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                    ${formatDate(ev.event_time)}
                </div>
                ${ev.location ? `<div class="event-meta-item">
                    <svg viewBox="0 0 24 24"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>
                    ${ev.location}
                </div>` : ''}
                <div class="event-meta-item">
                    <svg viewBox="0 0 24 24"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>
                    ${ev.attendee_count} / ${ev.max_participants}
                </div>
            </div>
            <div class="progress-bar-wrap">
                <div class="progress-bar-fill" style="width:${fill}%"></div>
            </div>
            <div class="event-footer">
                <div class="event-organizer" data-cid="${ev.citizenid}">
                    ${renderAvatar(ev.organizer_avatar, ev.organizer_name, 'avatar-sm')}
                    <span class="organizer-name">@${ev.organizer_name || _T('unknown')}</span>
                </div>
                <button class="btn-attend ${attending ? 'attending' : ''}" data-id="${ev.id}">
                    ${attending ? fa('check') + ' ' + _T('event_attending_btn') : _T('event_attend')}
                </button>
            </div>
        </div>
    `;

    div.querySelector('.event-organizer').addEventListener('click', () => openProfile(ev.citizenid));
    div.querySelector('.btn-attend').addEventListener('click', async () => {
        const btn = div.querySelector('.btn-attend');
        if (btn.classList.contains('attending')) {
            const res = await fetchNui('carspot:attendEvent', { id: ev.id });
            updateEventAttendUI(div, ev, btn, res);
            return;
        }
        setPopUp({
            title: _T('event_notify_title'),
            description: _T('event_notify_desc'),
            buttons: [
                {
                    title: _T('event_notify_yes'),
                    color: 'blue',
                    cb: () => confirmAttendEvent(ev, div, btn, true)
                },
                {
                    title: _T('event_notify_no'),
                    cb: () => confirmAttendEvent(ev, div, btn, false)
                }
            ]
        });
    });
    return div;
}

$('btn-create-event').addEventListener('click', () => {
    State.cePhotoData = null;
    ['ce-name','ce-desc','ce-location','ce-maxpart'].forEach(id => { $(id).value = id === 'ce-maxpart' ? '50' : ''; });
    $('ce-type').value = 'car_meet';
    $('ce-time').value = '';
    $('ce-photo-preview').innerHTML = photoPickerHtml('event_tap_banner');
    showView('create-event');
});

$('ce-photo-picker').addEventListener('click', () => {
    selectGallery({ includeImages: true, includeVideos: false, cb: (data) => {
        State.cePhotoData = data ? data.src || data : null;
        $('ce-photo-preview').innerHTML = State.cePhotoData
            ? `<img src="${State.cePhotoData}" style="width:100%;height:100%;object-fit:cover" />`
            : photoPickerHtml('event_tap_banner');
    }});
});

$('btn-submit-event').addEventListener('click', async () => {
    const name = $('ce-name').value.trim();
    if (!name) { showToast(_T('event_name_required'), 'error'); return; }
    $('btn-submit-event').disabled = true;
    const res = await fetchNui('carspot:createEvent', {
        name,
        description: $('ce-desc').value.trim(),
        type: $('ce-type').value,
        location: $('ce-location').value.trim(),
        event_time: $('ce-time').value || new Date().toISOString().slice(0, 16),
        max_participants: parseInt($('ce-maxpart').value) || 50,
        image: State.cePhotoData || ''
    });
    $('btn-submit-event').disabled = false;
    if (res.success) {
        showToast(res.message, 'success');
        showView('events', true);
        loadEvents();
    } else {
        showToast(res.message, 'error');
    }
});

async function loadRanking() {
    $('ranking-content').innerHTML = `<div class="loading-spinner"><div class="spinner"></div></div>`;
    const ranking = await fetchNui('carspot:getWeeklyRanking', {});
    $('ranking-content').innerHTML = '';

    const sections = [
        { key: 'most_voted', icon: 'trophy', label: _T('ranking_most_voted') },
        { key: 'supercar',   icon: 'gauge-high', label: _T('ranking_best_supercar') },
        { key: 'classic',    icon: 'car-rear', label: _T('ranking_best_classic') },
        { key: 'offroad',    icon: 'mountain', label: _T('ranking_best_offroad') },
    ];

    sections.forEach(({ key, icon, label }) => {
        const items = ranking[key] || [];
        const section = document.createElement('div');
        section.className = 'ranking-section';
        section.innerHTML = `<div class="ranking-section-title">${fa(icon)} ${label}</div>`;
        if (items.length === 0) {
            section.innerHTML += `<div class="no-results">${_T('ranking_no_entries')}</div>`;
        } else {
            items.forEach((p, i) => {
                const posClass = i === 0 ? 'gold' : i === 1 ? 'silver' : i === 2 ? 'bronze' : '';
                const card = document.createElement('div');
                card.className = 'ranking-card';
                card.innerHTML = `
                    <div class="ranking-pos ${posClass}">${i < 3 ? fa('medal') : i + 1}</div>
                    <div class="ranking-thumb">
                        ${p.image && p.image.length > 10
                            ? `<img src="${p.image}" loading="lazy" />`
                            : `<div class="ranking-thumb-placeholder">${fa('car')}</div>`}
                    </div>
                    <div class="ranking-info">
                        <div class="ranking-title">${p.title}</div>
                        <div class="ranking-author">@${p.username || _T('unknown')} · ${p.vehicle_model || ''}</div>
                    </div>
                    <div class="ranking-likes">
                        <svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/></svg>
                        ${p.recent_likes || p.likes_count || 0}
                    </div>
                `;
                card.addEventListener('click', () => openPost(p.id));
                section.appendChild(card);
            });
        }
        $('ranking-content').appendChild(section);
    });
}

async function submitComment() {
    if (!State.currentPostId) return;
    const input = $('comment-input');
    const text = input.value.trim();
    if (!text) return;
    input.value = '';
    const res = await fetchNui('carspot:commentPost', { id: State.currentPostId, content: text });
    if (res.success && res.comment) {
        const el = document.createElement('div');
        el.innerHTML = renderComment(res.comment);
        $('comments-list')?.appendChild(el.firstChild);
        showToast(res.message, 'success');
    } else {
        showToast(res.message, 'error');
    }
}

$('send-comment-btn').addEventListener('click', submitComment);
$('comment-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') submitComment();
});

function applyTheme(settings) {
    if (!settings) return;
    const theme = (settings.display && settings.display.theme) || settings.theme;
    if (theme !== 'light' && theme !== 'dark') return;
    const app = document.getElementsByClassName('app')[0];
    if (app) app.dataset.theme = theme;
    document.body.dataset.theme = theme;
}

/** Dark UI — request white status-bar icons when running inside sd-phone. */
function requestLightStatusBar() {
    const c = globalThis.components;
    if (c && typeof c.setStatusLight === 'function') {
        c.setStatusLight(true);
        return;
    }
    if (c && typeof c.setStatusLightOverride === 'function') {
        c.setStatusLightOverride(true);
        return;
    }
    if (c && typeof c.fetchPhone === 'function') {
        c.fetchPhone('SetStatusLight', true);
    }
}

async function initApp() {
    await loadLocales();
    loadFeed(true);
    requestLightStatusBar();

    const getSettingsFn = typeof getSettings === 'function' ? getSettings
        : (typeof GetSettings === 'function' ? GetSettings : null);
    const onSettingsChangeFn = typeof onSettingsChange === 'function' ? onSettingsChange
        : (typeof OnSettingsChange === 'function' ? OnSettingsChange : null);

    if (!getSettingsFn) return;

    if (onSettingsChangeFn) onSettingsChangeFn(applyTheme);

    try {
        applyTheme(await getSettingsFn());
    } catch (e) {}
}
